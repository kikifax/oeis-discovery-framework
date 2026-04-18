require 'raylib'
require 'json'
require 'prime'
require_relative '../sequence_template'

# Initialize Raylib Library
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

  # THEME COLORS
  BG_DARK    = Color.new(18, 18, 22, 255) 
  SIDEBAR_BG = Color.new(28, 28, 33, 255)
  ACCENT     = Color.new(0, 150, 255, 255)
  TEXT_MAIN  = Color.new(230, 230, 240, 255)
  TEXT_DIM   = Color.new(120, 120, 135, 255)

  SIDEBAR_W = 380.0

  def initialize
    @sequences = load_sequences_metadata
    @current_idx = 0
    @num_terms = 2000
    @scroll_offset = 0.0
    @dragging = false
    
    # Viewport state
    @offset_x = SIDEBAR_W + 50.0
    @offset_y = 500.0
    @zoom_x = 0.5
    @zoom_y = 0.1
    @terms = []
    
    $stdout.sync = true
    puts "[VIEWER] Initialized Object v#{OEIS::VERSION}"
  end

  def load_sequences_metadata
    cache_path = File.join(Dir.pwd, '.cache', 'catalog.json')
    if File.exist?(cache_path)
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
        data.sort_by { |s| -s[:score] }
      rescue
        []
      end
    else
      []
    end
  end

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)

    puts "[VIEWER] Loading sequence: #{key}"
    existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
    begin
      require file
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = new_classes.find { |c| c.to_s.downcase.include?(key.gsub('_', '')) }
      klass ||= (new_classes - existing_classes).first
      
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        
        doc_path = File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")
        @doc_lines = File.exist?(doc_path) ? File.read(doc_path).lines.map(&:strip) : ["No documentation found."]
        @doc_lines = @doc_lines.reject { |l| l.start_with?("Doc Version:") || l.strip.empty? }
        
        auto_fit_all()
      end
    rescue => e
      puts "[VIEWER] Error loading #{key}: #{e.message}"
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    return if w == 0 # Window not ready
    
    max_v, min_v = @terms.max, @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    
    padding = 100.0
    @zoom_y = (h - padding * 2) / range_y
    @offset_y = padding + (max_v * @zoom_y)

    padding_x = 60.0
    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + padding_x
    puts "[VIEWER] Fit completed for #{@num_terms} terms."
  end

  def auto_fit_y_visible
    return if @terms.nil? || @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    return if w == 0
    
    start_i = [((- @offset_x + SIDEBAR_W) / @zoom_x).floor, 0].max
    end_i = [((w - @offset_x) / @zoom_x).ceil, @terms.size - 1].min
    return if start_i >= @terms.size || end_i < 0 || start_i >= end_i
    
    slice = @terms[start_i..end_i]
    return if slice.nil? || slice.empty?
    
    max_v, min_v = slice.max, slice.min
    range_y = [(max_v - min_v).abs, 1.0].max
    
    padding_y = 100.0 
    @zoom_y = (h - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE)
    InitWindow(1600, 950, "OEIS Discovery Station v#{OEIS::VERSION}")
    SetTargetFPS(60)
    
    # CRITICAL: Load the first sequence ONLY AFTER InitWindow
    if @sequences.any?
      load_sequence(@sequences[0][:key])
    else
      @doc_lines = ["No sequences found.", "Run 'ruby oeis_cli.rb build-catalog'"]
    end

    begin
      until WindowShouldClose()
        update()
        draw()
      end
    rescue => e
      puts "[CRASH] An error occurred in the main loop:"
      puts e.message
      puts e.backtrace.join("\n")
      sleep 5 # Keep console open to read error
    ensure
      CloseWindow()
    end
  end

  def update
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    mx, my = GetMouseX().to_f, GetMouseY().to_f

    if mx < SIDEBAR_W
      @scroll_offset += GetMouseWheelMove() * 35
      @scroll_offset = [@scroll_offset, 0].min
      max_scroll = -(@sequences.size * 32 - (h - 520))
      @scroll_offset = [@scroll_offset, max_scroll].max if max_scroll < 0

      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        list_y = 90.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if my >= list_y && my < list_y + 32
            @current_idx = i
            load_sequence(s[:key])
            break
          end
          list_y += 32
        end
      end
    else
      # GRAPH INTERACTION
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        @dragging = true
        @last_mouse_x = mx
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
    ClearBackground(BG_DARK)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # --- GRAPH ---
    axis_color = Color.new(50, 50, 60, 255)
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, w.to_i, @offset_y.to_i, axis_color) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, axis_color)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1, x2 = @offset_x + (i - 1) * @zoom_x, @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1, y2 = @offset_y - @terms[i - 1] * @zoom_y, @offset_y - @terms[i] * @zoom_y
        
        # Draw with slight Glow (Ex functions take Vector2)
        DrawLineEx(Vector2.new(x1, y1), Vector2.new(x2, y2), 1.5, ACCENT)
      end
    end

    # --- SIDEBAR ---
    DrawRectangle(0, 0, SIDEBAR_W.to_i, h.to_i, SIDEBAR_BG)
    DrawRectangle(SIDEBAR_W.to_i - 1, 0, 1, h.to_i, Color.new(255, 255, 255, 15))

    DrawText("EXPLORER", 30, 30, 22, WHITE)
    DrawText("V#{OEIS::VERSION}", 150, 38, 12, ACCENT)

    # Scissored List Area
    list_h = [h - 520, 10].max
    BeginScissorMode(0, 80, SIDEBAR_W.to_i, list_h.to_i)
      list_y = 90.0 + @scroll_offset
      mx, my = GetMouseX(), GetMouseY()
      
      @sequences.each_with_index do |s, i|
        is_hovered = mx > 20 && mx < SIDEBAR_W - 20 && my > list_y && my < list_y + 32
        text_color = (i == @current_idx) ? WHITE : (is_hovered ? TEXT_MAIN : TEXT_DIM)
        
        if i == @current_idx
          DrawRectangle(25, list_y.to_i - 4, (SIDEBAR_W - 50).to_i, 30, Color.new(255, 255, 255, 15))
          DrawRectangle(25, list_y.to_i - 4, 3, 30, ACCENT)
        end
        
        DrawText(s[:display], 40, list_y.to_i, 17, text_color)
        list_y += 32
      end
    EndScissorMode()

    # Documentation Panel
    panel_y = h - 420
    DrawRectangle(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 400, Color.new(20, 20, 25, 255))
    DrawRectangleLines(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 400, Color.new(60, 60, 70, 255))
    DrawText("MATHEMATICAL ANALYSIS", 35, panel_y.to_i + 15, 12, ACCENT)
    
    y_ptr = panel_y + 45
    (@doc_lines || []).each do |line|
      next if line.start_with?("# ") || line.strip.empty?
      clean_line = line.gsub("**", "").gsub(">", "")
      DrawText(clean_line[0..45], 35, y_ptr.to_i, 11, TEXT_DIM)
      y_ptr += 16
      break if y_ptr > h - 30
    end

    # Top Header Info
    title = @instance ? @instance.name : "Select a sequence"
    DrawText(title.upcase, SIDEBAR_W.to_i + 25, 15, 22, TEXT_MAIN)
    DrawText("TERMS: #{@num_terms}", w.to_i - 150, 18, 16, ACCENT)

    EndDrawing()
  end
end

RaylibExplorer.new.run
