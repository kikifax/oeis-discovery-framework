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

  # THEME COLORS
  BG_DARK    = Color.create(18, 18, 22, 255)    # Cyber Black
  SIDEBAR_BG = Color.create(30, 30, 35, 255)    # Slate
  ACCENT     = Color.create(0, 170, 255, 255)   # Neon Blue
  TEXT_MAIN  = Color.create(220, 220, 230, 255) # Off-white
  TEXT_DIM   = Color.create(130, 130, 145, 255) # Muted gray

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
      []
    end
  end

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)

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
      puts "Error loading #{key}: #{e.message}"
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    max_v, min_v = @terms.max, @terms.min
    range_y = [max_v - min_v, 1.0].max
    
    padding = 100.0
    @zoom_y = (h - padding * 2) / range_y
    @offset_y = padding + (max_v * @zoom_y)

    padding_x = 60.0
    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + padding_x
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE)
    InitWindow(1600, 950, "OEIS Obsidian Explorer v#{OEIS::VERSION}")
    SetTargetFPS(60)
    # SetWindowState(FLAG_WINDOW_MAXIMIZED) # Optional: Starts maximized

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
      max_scroll = -(@sequences.size * 30 - (h - 500))
      @scroll_offset = [@scroll_offset, max_scroll].max if max_scroll < 0

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
      load_sequence(@sequences[@current_idx][:key])
    elsif IsKeyPressed(KEY_DOWN) && @num_terms > 500
      @num_terms -= 500
      load_sequence(@sequences[@current_idx][:key])
    end
  end

  def draw
    BeginDrawing()
    ClearBackground(BG_DARK)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # --- GRAPH ---
    # Axes
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, w.to_i, @offset_y.to_i, Color.create(50, 50, 60, 255)) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, Color.create(50, 50, 60, 255))

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1, x2 = @offset_x + (i - 1) * @zoom_x, @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1, y2 = @offset_y - @terms[i - 1] * @zoom_y, @offset_y - @terms[i] * @zoom_y
        DrawLineEx(Vector2.create(x1, y1), Vector2.create(x2, y2), 1.5, ACCENT)
      end
    end

    # --- SIDEBAR ---
    DrawRectangle(0, 0, SIDEBAR_W.to_i, h.to_i, SIDEBAR_BG)
    DrawRectangle(SIDEBAR_W.to_i - 2, 0, 2, h.to_i, Color.create(0, 0, 0, 50)) # Subtle shadow

    DrawText("SEQUENCE CATALOG", 25, 25, 18, TEXT_MAIN)
    DrawRectangle(25, 52, 60, 3, ACCENT) # Accent bar

    # Scissored List
    BeginScissorMode(0, 70, SIDEBAR_W.to_i, (h - 480).to_i)
      list_y = 80.0 + @scroll_offset
      mx, my = GetMouseX(), GetMouseY()
      
      @sequences.each_with_index do |s, i|
        is_hovered = mx > 20 && mx < SIDEBAR_W - 20 && my > list_y && my < list_y + 30
        text_color = (i == @current_idx) ? WHITE : (is_hovered ? TEXT_MAIN : TEXT_DIM)
        
        if i == @current_idx
          DrawRectangle(20, list_y.to_i - 5, (SIDEBAR_W - 40).to_i, 28, Color.create(255, 255, 255, 20))
        end
        
        DrawText(s[:display], 30, list_y.to_i, 16, text_color)
        list_y += 30
      end
    EndScissorMode()

    # Analysis Area
    panel_y = h - 400
    DrawRectangle(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 380, BG_DARK)
    DrawRectangleLines(20, panel_y.to_i, (SIDEBAR_W - 40).to_i, 380, Color.create(60, 60, 70, 255))
    DrawText("ANALYSIS", 35, panel_y.to_i + 15, 14, ACCENT)
    
    y_ptr = panel_y + 45
    (@doc_lines || []).each do |line|
      next if line.start_with?("# ") || line.strip.empty?
      DrawText(line[0..50], 35, y_ptr.to_i, 11, TEXT_DIM)
      y_ptr += 16
      break if y_ptr > h - 40
    end

    # Top Header
    DrawRectangle(SIDEBAR_W.to_i, 0, (w - SIDEBAR_W).to_i, 50, Color.create(0, 0, 0, 80))
    title = @instance ? @instance.name : "Select a sequence"
    DrawText(title.upcase, SIDEBAR_W.to_i + 25, 15, 22, TEXT_MAIN)
    DrawText("TERMS: #{@num_terms}", w.to_i - 150, 18, 16, ACCENT)

    # Help Legend
    DrawText("WHEEL: Zoom | DRAG: Pan | R: Fit | UP/DOWN: Terms", SIDEBAR_W.to_i + 25, h.to_i - 30, 14, TEXT_DIM)

    EndDrawing()
  end
end

RaylibExplorer.new.run
