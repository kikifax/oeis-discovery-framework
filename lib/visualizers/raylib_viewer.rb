require 'raylib'
require 'json'
require 'prime'
require_relative '../sequence_template'

# Initialize Raylib
shared_lib_path = Gem::Specification.find_by_name('raylib-bindings').full_gem_path + '/lib/'
case RUBY_PLATFORM
when /mswin|msys|mingw|cygwin/
  Raylib.load_lib(shared_lib_path + 'libraylib.dll')
when /darwin/
  arch = RUBY_PLATFORM.split('-')[0]
  Raylib.load_lib(shared_lib_path + "libraylib.#{arch}.dylib")
when /linux/
  arch = RUBY_PLATFORM.split('-')[0]
  Raylib.load_lib(shared_lib_path + "libraylib.#{arch}.so")
end

class RaylibExplorer
  include Raylib

  SIDEBAR_W = 380.0

  def initialize
    @sequences = load_catalog
    @current_idx = 0
    @num_terms = 2000
    @scroll_offset = 0.0
    @dragging = false
    @terms = []
    
    @offset_x = SIDEBAR_W + 50.0
    @offset_y = 450.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    
    $stdout.sync = true
    puts "[Station] Initialized Explorer v#{OEIS::VERSION}"
  end

  # Safe Color Factory for Windows FFI
  def make_color(r, g, b, a=255)
    c = Raylib::Color.new
    c[:r], c[:g], c[:b], c[:a] = r, g, b, a
    c
  end

  def init_theme
    @bg_dark    = make_color(20, 20, 25)
    @sidebar_bg = make_color(30, 30, 40)
    @accent     = make_color(0, 180, 255)
    @text_main  = make_color(240, 240, 250)
    @text_dim   = make_color(150, 150, 170)
    @axis_c     = make_color(60, 60, 70)
    @hover_bg   = make_color(255, 255, 255, 20)
    @panel_bg   = make_color(15, 15, 20)
  end

  def load_catalog
    cache_path = File.join(Dir.pwd, '.cache', 'catalog.json')
    return [] unless File.exist?(cache_path)
    begin
      data = JSON.parse(File.read(cache_path))
      data.map! do |s|
        { 
          key: s['key'], 
          name: s['name'], 
          score: s['fitness_score'] || 0,
          display: "[#{s['fitness_score'].to_i.to_s.rjust(3)}] #{s['name']}"
        }
      end
      data.sort_by { |s| -(s[:score] || 0) }
    rescue
      []
    end
  end

  def load_sequence_class(file)
    existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
    begin
      require File.expand_path(file)
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      key = File.basename(file, '.rb').gsub('_', '')
      klass = new_classes.find { |c| c.to_s.downcase.include?(key) }
      klass || (new_classes - existing_classes).first
    rescue
      nil
    end
  end

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)

    begin
      klass = load_sequence_class(file)
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        
        doc_path = File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")
        @doc_lines = File.exist?(doc_path) ? File.read(doc_path).lines.reject{|l| l.start_with?("#")}.first(25).map(&:strip) : ["No docs."]
        
        auto_fit_all()
        puts "[Station] Loaded: #{key}"
      end
    rescue => e
      puts "Error loading #{key}: #{e.message}"
    end
  end

  def auto_fit_all
    return if @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    return if w == 0
    
    max_v, min_v = @terms.max, @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    
    @zoom_y = (h - 200.0) / range_y
    @offset_y = 100.0 + (max_v * @zoom_y)

    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - 100.0) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + 50.0
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE)
    InitWindow(1600, 950, "OEIS Discovery Station v#{OEIS::VERSION}")
    SetTargetFPS(60)
    
    init_theme()

    # Initial Load
    load_sequence(@sequences[0][:key]) if @sequences.any?

    until WindowShouldClose()
      update()
      draw()
    end
    CloseWindow()
  end

  def update
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    mx, my = GetMouseX().to_f, GetMouseY().to_f

    if mx < SIDEBAR_W
      @scroll_offset += GetMouseWheelMove() * 30
      @scroll_offset = [@scroll_offset, 0].min
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        list_y = 80.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if my >= list_y && my < list_y + 30
            @current_idx = i
            load_sequence(s[:key])
            break
          end
          list_y += 30
        end
      end
    else
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        @dragging = true; @last_mouse_x = mx
      elsif IsMouseButtonReleased(MOUSE_BUTTON_LEFT)
        @dragging = false
      end
      if @dragging
        @offset_x += (mx - @last_mouse_x)
        @last_mouse_x = mx
      end
      wheel = GetMouseWheelMove()
      @zoom_x *= (wheel > 0 ? 1.2 : 0.8) if wheel != 0
      auto_fit_all() if IsKeyPressed(KEY_R)
    end
    
    if IsKeyPressed(KEY_UP)
      @num_terms += 500
      load_sequence(@sequences[@current_idx][:key]) if @sequences[@current_idx]
    elsif IsKeyPressed(KEY_DOWN) && @num_terms > 500
      @num_terms -= 500
      load_sequence(@sequences[@current_idx][:key]) if @sequences[@current_idx]
    end
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # --- GRAPH ---
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, w.to_i, @offset_y.to_i, @axis_c)
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, @axis_c)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1 = @offset_y - @terms[i-1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        DrawLineEx(Vector2.new(x1, y1), Vector2.new(x2, y2), 1.5, @accent)
      end
    end

    # --- SIDEBAR ---
    DrawRectangle(0, 0, SIDEBAR_W.to_i, h.to_i, @sidebar_bg)
    DrawText("EXPLORER", 30, 30, 24, WHITE)

    BeginScissorMode(0, 80, SIDEBAR_W.to_i, (h - 450).to_i)
      list_y = 80.0 + @scroll_offset
      @sequences.each_with_index do |s, i|
        color = (i == @current_idx) ? WHITE : @text_dim
        if i == @current_idx
          DrawRectangle(20, list_y.to_i - 2, (SIDEBAR_W - 40).to_i, 25, @hover_bg)
        end
        DrawText(s[:display], 30, list_y.to_i, 16, color)
        list_y += 30
      end
    EndScissorMode()

    # Analysis Box
    panel_y = h - 350
    DrawRectangle(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 330, @panel_bg)
    DrawText("ANALYSIS", 35, panel_y.to_i + 15, 14, @accent)
    y_ptr = panel_y + 45
    (@doc_lines || []).each do |line|
      next if line.strip.empty?
      DrawText(line[0..45], 35, y_ptr.to_i, 11, @text_dim)
      y_ptr += 15
      break if y_ptr > h - 40
    end

    DrawText(@instance ? @instance.name.upcase : "Select", SIDEBAR_W.to_i + 30, 15, 22, TEXT_MAIN)
    EndDrawing()
  end
end

RaylibExplorer.new.run
