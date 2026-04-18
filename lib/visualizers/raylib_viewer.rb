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

  # UI CONSTANTS
  SIDEBAR_W = 350.0
  WIN_W = 1600
  WIN_H = 900

  def initialize
    @sequences = load_sequences_metadata
    @current_idx = 0
    @num_terms = 2000
    @num_terms_text = @num_terms.to_s
    
    # Viewport state
    @offset_x = SIDEBAR_W + 50.0
    @offset_y = 450.0
    @zoom_x = 0.5
    @zoom_y = 0.1
    
    # UI Interaction
    @scroll_offset = 0.0
    @dragging = false
    @edit_mode = false # For terms input
    
    $stdout.sync = true
    load_sequence(@sequences[0][:key])
  end

  def load_sequences_metadata
    cache_path = File.join(Dir.pwd, '.cache', 'catalog.json')
    if File.exist?(cache_path)
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
    else
      [] # Fallback if catalog not built
    end
  end

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)

    # Dynamic Class Discovery
    existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
    begin
      require file
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = new_classes.find { |c| c.to_s.downcase.include?(key.gsub('_', '')) }
      klass ||= (new_classes - existing_classes).first
      
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        
        # Load doc text
        doc_path = File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")
        @doc_lines = File.exist?(doc_path) ? File.read(doc_path).lines.map(&:strip) : ["No docs found."]
        
        auto_fit_all()
      end
    rescue => e
      puts "Error loading #{key}: #{e.message}"
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    max_v, min_v = @terms.max, @terms.min
    range_y = [max_v - min_v, 1.0].max
    
    padding = 80.0
    @zoom_y = (WIN_H - padding * 2) / range_y
    @offset_y = padding + (max_v * @zoom_y)

    padding_x = 50.0
    graph_area_w = WIN_W - SIDEBAR_W
    @zoom_x = (graph_area_w - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + padding_x
  end

  def run
    InitWindow(WIN_W, WIN_H, "OEIS Discovery Station v#{OEIS::VERSION}")
    SetTargetFPS(60)

    until WindowShouldClose()
      update()
      draw()
    end

    CloseWindow()
  end

  def update
    mx, my = GetMouseX().to_f, GetMouseY().to_f

    # 1. SIDEBAR INTERACTION
    if mx < SIDEBAR_W
      # Scrolling
      @scroll_offset += GetMouseWheelMove() * 20
      @scroll_offset = [@scroll_offset, 0].min
      
      # Clicking a sequence
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
        # Check list items
        list_y = 60.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if my >= list_y && my < list_y + 25
            @current_idx = i
            load_sequence(s[:key])
            break
          end
          list_y += 25
        end
      end
    else
      # 2. GRAPH INTERACTION
      # Panning
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

      # Zooming
      wheel = GetMouseWheelMove()
      if wheel != 0
        @zoom_x *= (wheel > 0 ? 1.2 : 0.8)
      end
      
      auto_fit_all() if IsKeyPressed(KEY_R)
    end
    
    # Hotkeys
    if IsKeyPressed(KEY_UP)
      @num_terms += 500
      load_sequence(@sequences[@current_idx][:key])
    elsif IsKeyPressed(KEY_DOWN) && @num_terms > 500
      @num_terms -= 500
      load_sequence(@sequences[@current_idx][:key])
    end
  end

  def draw
    BeginDrawing()
    ClearBackground(RAYWHITE)

    # --- SIDEBAR ---
    DrawRectangle(0, 0, SIDEBAR_W.to_i, WIN_H, GetColor(0xF0F0F5FF))
    DrawLine(SIDEBAR_W.to_i, 0, SIDEBAR_W.to_i, WIN_H, LIGHTGRAY)
    
    DrawText("DISCOVERIES (Sorted by Score)", 15, 15, 10, GRAY)
    
    # Scissored List Area
    BeginScissorMode(0, 40, SIDEBAR_W.to_i, 400)
      list_y = 60.0 + @scroll_offset
      @sequences.each_with_index do |s, i|
        color = (i == @current_idx) ? DARKBLUE : BLACK
        bg_color = (i == @current_idx) ? Fade(SKYBLUE, 0.3) : Fade(WHITE, 0.0)
        
        DrawRectangle(10, list_y.to_i - 2, (SIDEBAR_W - 20).to_i, 22, bg_color)
        DrawText(s[:display], 15, list_y.to_i, 15, color)
        list_y += 25
      end
    EndScissorMode()

    # Documentation Preview Area
    DrawRectangle(10, 460, (SIDEBAR_W - 20).to_i, 420, WHITE)
    DrawRectangleLines(10, 460, (SIDEBAR_W - 20).to_i, 420, LIGHTGRAY)
    DrawText("ANALYSIS & DOCS", 20, 475, 12, DARKBLUE)
    
    y_ptr = 510
    (@doc_lines || []).each do |line|
      next if line.start_with?("Doc Version:")
      DrawText(line[0..45], 20, y_ptr, 10, BLACK)
      y_ptr += 15
      break if y_ptr > 860
    end

    # --- GRAPH AREA ---
    # Draw Grid/Axes
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, WIN_W, @offset_y.to_i, LIGHTGRAY) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, WIN_H, LIGHTGRAY)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1, x2 = @offset_x + (i - 1) * @zoom_x, @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > WIN_W
        y1, y2 = @offset_y - @terms[i - 1] * @zoom_y, @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, BLUE)
      end
    end

    # Header Overlay
    DrawRectangle(SIDEBAR_W.to_i, 0, (WIN_W - SIDEBAR_W).to_i, 40, Fade(SKYBLUE, 0.8))
    title = @instance ? @instance.name : "Select a sequence"
    DrawText("#{title} | Terms: #{@num_terms}", SIDEBAR_W.to_i + 20, 10, 20, DARKBLUE)
    
    DrawText("Drag: Pan X | Wheel: Zoom X | R: Fit All | Up/Down: Change Terms", SIDEBAR_W.to_i + 20, WIN_H - 25, 15, GRAY)

    EndDrawing()
  end
end

RaylibExplorer.new.run
