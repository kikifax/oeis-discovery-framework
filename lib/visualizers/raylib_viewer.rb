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
    @input_text = @num_terms.to_s
    @edit_mode = false
    @scroll_offset = 0.0
    @dragging = false
    @terms = []
    
    @offset_x = SIDEBAR_W + 50.0
    @offset_y = 450.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    
    $stdout.sync = true
  end

  def make_color(r, g, b, a=255)
    c = Raylib::Color.new
    c[:r], c[:g], c[:b], c[:a] = r, g, b, a
    c
  end

  def init_theme
    @bg_dark    = make_color(18, 18, 22)
    @sidebar_bg = make_color(28, 28, 35)
    @accent     = make_color(0, 180, 255)
    @text_main  = make_color(230, 230, 240)
    @text_dim   = make_color(135, 135, 155)
    @axis_c     = make_color(50, 50, 60)
    @hover_bg   = make_color(255, 255, 255, 15)
    @panel_bg   = make_color(12, 12, 16)
    
    # Try to load a professional system font
    font_paths = [
      "C:/Windows/Fonts/consola.ttf",    # Consolas (Best for math/code)
      "C:/Windows/Fonts/arial.ttf",      # Arial
      "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", # Linux
      "/System/Library/Fonts/Menlo.ttc"  # macOS
    ]
    
    @font = nil
    font_paths.each do |path|
      if File.exist?(path)
        @font = LoadFontEx(path, 64, nil, 0)
        break if @font
      end
    end
    @font ||= GetFontDefault() # Fallback
    puts "[Station] Theme and Typography initialized."
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
    rescue; []; end
  end

  def load_sequence_class(file)
    begin
      existing = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require File.expand_path(file)
      found = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      key = File.basename(file, '.rb').gsub('_', '')
      found.find { |c| c.to_s.downcase.include?(key) } || (found - existing).first
    rescue; nil; end
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
        
        # Doc Path
        root = File.expand_path("../../..", __FILE__)
        doc_path = File.join(root, 'docs', 'sequences', "#{key}.md")
        if File.exist?(doc_path)
          @doc_lines = File.read(doc_path).lines.reject{|l| l.start_with?("#", "Doc Version:") || l.strip.empty? }.first(25).map(&:strip)
        else
          @doc_lines = ["Documentation missing."]
        end
        
        auto_fit_all()
      end
    rescue; end
  end

  def auto_fit_all
    return if @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    return if w == 0
    max_v, min_v = @terms.max, @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    @zoom_y = (h - 250.0) / range_y
    @offset_y = 100.0 + (max_v * @zoom_y)
    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - 120.0) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + 60.0
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_MSAA_4X_HINT | FLAG_WINDOW_HIGHDPI)
    InitWindow(1600, 950, "OEIS Discovery Station v#{OEIS::VERSION}")
    SetTargetFPS(60)
    init_theme()

    load_sequence(@sequences[0][:key]) if @sequences.any?

    until WindowShouldClose()
      update()
      draw()
    end
    CloseWindow()
  end

  def draw_text_pro(text, x, y, size, color)
    DrawTextEx(@font, text, Vector2.new(x, y), size.to_f, 1.0, color)
  end

  def update
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    mx, my = GetMouseX().to_f, GetMouseY().to_f

    if @edit_mode
      key = GetCharPressed()
      while key > 0
        @input_text << key.chr if (key >= 48) && (key <= 57)
        key = GetCharPressed()
      end
      @input_text = @input_text[0...-1] if IsKeyPressed(KEY_BACKSPACE) && @input_text.length > 0
      if IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_KP_ENTER)
        @num_terms = @input_text.to_i if @input_text.to_i > 0
        load_sequence(@sequences[@current_idx][:key])
        @edit_mode = false
      end
      @edit_mode = false if IsKeyPressed(KEY_ESCAPE)
      return
    end

    if mx < SIDEBAR_W
      @scroll_offset += GetMouseWheelMove() * 40
      @scroll_offset = [@scroll_offset, 0].min
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        list_y = 100.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if my >= list_y && my < list_y + 32
            @current_idx = i; load_sequence(s[:key])
            break
          end
          list_y += 32
        end
      end
    else
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        if my < 60 && mx > w - 250
          @edit_mode = true
        else
          @dragging = true; @last_mouse_x = mx
        end
      elsif IsMouseButtonReleased(MOUSE_BUTTON_LEFT); @dragging = false; end
      if @dragging; @offset_x += (mx - @last_mouse_x); @last_mouse_x = mx; end
      @zoom_x *= (GetMouseWheelMove() > 0 ? 1.2 : 0.8) if GetMouseWheelMove() != 0
      auto_fit_all() if IsKeyPressed(KEY_R)
    end
    @edit_mode = true if IsKeyPressed(KEY_T)
    if IsKeyPressed(KEY_UP) || IsKeyPressed(KEY_DOWN)
      @num_terms += (IsKeyPressed(KEY_UP) ? 500 : -500)
      @num_terms = 500 if @num_terms < 500
      @input_text = @num_terms.to_s
      load_sequence(@sequences[@current_idx][:key])
    end
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # GRAPH
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, w.to_i, @offset_y.to_i, @axis_c)
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, @axis_c)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1, x2 = @offset_x + (i - 1) * @zoom_x, @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1, y2 = @offset_y - @terms[i-1] * @zoom_y, @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, @accent)
      end
    end

    # SIDEBAR
    DrawRectangle(0, 0, SIDEBAR_W.to_i, h.to_i, @sidebar_bg)
    DrawRectangle(SIDEBAR_W.to_i - 1, 0, 1, h.to_i, make_color(255, 255, 255, 30))
    draw_text_pro("EXPLORER STATION", 30, 35, 20, WHITE)
    DrawRectangle(30, 65, 40, 2, @accent)

    BeginScissorMode(0, 90, SIDEBAR_W.to_i, (h - 480).to_i)
      list_y = 105.0 + @scroll_offset
      @sequences.each_with_index do |s, i|
        color = (i == @current_idx) ? WHITE : @text_dim
        if i == @current_idx
          DrawRectangle(25, list_y.to_i - 4, (SIDEBAR_W - 50).to_i, 30, @hover_bg)
          DrawRectangle(25, list_y.to_i - 4, 3, 30, @accent)
        end
        draw_text_pro(s[:display], 40, list_y.to_i, 16, color)
        list_y += 32
      end
    EndScissorMode()

    # Documentation
    panel_y = h - 350
    DrawRectangle(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 330, @panel_bg)
    DrawRectangleLines(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 330, @axis_c)
    draw_text_pro("MATHEMATICAL ANALYSIS", 35, panel_y.to_i + 15, 12, @accent)
    y_ptr = panel_y + 45
    (@doc_lines || []).each do |line|
      draw_text_pro(line[0..45], 35, y_ptr.to_i, 13, @text_dim)
      y_ptr += 18
      break if y_ptr > h - 40
    end

    # HEADER
    header_c = @edit_mode ? @accent : @text_main
    name = @instance ? @instance.name.upcase : "SELECT"
    draw_text_pro(name, SIDEBAR_W.to_i + 30, 20, 22, @text_main)
    
    terms_val = "TERMS: #{@edit_mode ? @input_text + '_' : @num_terms}"
    draw_text_pro(terms_val, w.to_i - 250, 24, 18, header_c)

    draw_text_pro("WHEEL: Zoom | DRAG: Pan | R: Fit | T: Edit Terms", SIDEBAR_W.to_i + 30, h.to_i - 30, 14, @text_dim)

    EndDrawing()
  end
end

RaylibExplorer.new.run
