require 'raylib'
require 'json'
require 'prime'
require_relative '../sequence_template'

# Initialize Raylib Library
puts "[DEBUG] Locating Raylib shared library..."
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
puts "[DEBUG] Raylib library loaded."

class RaylibExplorer
  include Raylib

  # THEME COLORS (Using simple Color.new)
  SIDEBAR_W = 380.0

  def initialize
    puts "[DEBUG] Initializing RaylibExplorer object..."
    @sequences = load_sequences_metadata
    @current_idx = 0
    @num_terms = 2000
    @scroll_offset = 0.0
    @dragging = false
    
    @offset_x = SIDEBAR_W + 50.0
    @offset_y = 500.0
    @zoom_x = 0.5
    @zoom_y = 0.1
    @terms = []
    
    $stdout.sync = true
    puts "[DEBUG] Object ready. Sequences found: #{@sequences.size}"
  end

  def load_sequences_metadata
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
      data.sort_by { |s| -s[:score] }
    rescue => e
      puts "[DEBUG] Metadata error: #{e.message}"
      []
    end
  end

  def load_sequence(key)
    puts "[DEBUG] Loading sequence: #{key}"
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)

    begin
      # Use basic require
      require file
      # Heuristic to find class
      class_name = key.split('_').map(&:capitalize).join
      klass = Object.const_get(class_name) rescue nil
      
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        puts "[DEBUG] Generated #{@terms.size} terms."
        
        doc_path = File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")
        @doc_lines = File.exist?(doc_path) ? File.read(doc_path).lines.map(&:strip) : ["No documentation found."]
        @doc_lines = @doc_lines.reject { |l| l.start_with?("Doc Version:") || l.strip.empty? }
        
        auto_fit_all()
      else
        puts "[DEBUG] Failed to find class for #{key}"
      end
    rescue => e
      puts "[DEBUG] Error loading #{key}: #{e.message}"
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    w = GetScreenWidth()
    h = GetScreenHeight()
    return if w <= 0
    
    max_v, min_v = @terms.max, @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    
    padding = 100.0
    @zoom_y = (h - padding * 2) / range_y
    @offset_y = padding + (max_v * @zoom_y)

    padding_x = 60.0
    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + padding_x
    puts "[DEBUG] Scaling complete. ZoomX: #{@zoom_x.round(4)}"
  end

  def run
    puts "[DEBUG] Setting Window Flags..."
    SetConfigFlags(FLAG_WINDOW_RESIZABLE)
    puts "[DEBUG] Opening Window..."
    InitWindow(1600, 950, "OEIS Diagnostic Explorer v#{OEIS::VERSION}")
    SetTargetFPS(60)
    puts "[DEBUG] Window Open. Resolution: #{GetScreenWidth()}x#{GetScreenHeight()}"
    
    if @sequences.any?
      load_sequence(@sequences[0][:key])
    else
      @doc_lines = ["No sequences found.", "Run build-catalog."]
    end

    puts "[DEBUG] Entering Main Loop..."
    begin
      until WindowShouldClose()
        update()
        draw()
      end
    rescue => e
      puts "[CRASH] Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    ensure
      puts "[DEBUG] Closing Window..."
      CloseWindow()
    end
    puts "[DEBUG] Execution finished."
  end

  def update
    # Use instance vars for colors inside the loop to be safe
    @bg_dark ||= Color.new(18, 18, 22, 255)
    @accent  ||= Color.new(0, 150, 255, 255)
    @sidebar ||= Color.new(28, 28, 33, 255)
    @text_white ||= Color.new(230, 230, 240, 255)

    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    mx, my = GetMouseX().to_f, GetMouseY().to_f

    if mx < SIDEBAR_W
      @scroll_offset += GetMouseWheelMove() * 35
      @scroll_offset = [@scroll_offset, 0].min
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
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # Axes
    axis_c = Color.new(50, 50, 60, 255)
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, w.to_i, @offset_y.to_i, axis_c) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, axis_c)

    # Sequence (Simple DrawLine to avoid Vector2)
    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1 = @offset_y - @terms[i - 1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, @accent)
      end
    end

    # Sidebar
    DrawRectangle(0, 0, SIDEBAR_W.to_i, h.to_i, @sidebar)
    DrawText("CATALOG", 30, 30, 22, @text_white)

    # Scissored List
    list_h = [h - 520, 10].max
    BeginScissorMode(0, 80, SIDEBAR_W.to_i, list_h.to_i)
      list_y = 90.0 + @scroll_offset
      @sequences.each_with_index do |s, i|
        color = (i == @current_idx) ? WHITE : @text_white
        DrawText(s[:display], 40, list_y.to_i, 17, color)
        list_y += 32
      end
    EndScissorMode()

    # Header
    DrawText(@instance ? @instance.name : "Select...", SIDEBAR_W.to_i + 25, 15, 22, @text_white)
    
    EndDrawing()
  end
end

puts "[DEBUG] Starting RaylibExplorer.new.run"
RaylibExplorer.new.run
