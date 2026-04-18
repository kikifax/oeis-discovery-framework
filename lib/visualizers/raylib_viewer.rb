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

class RaylibViewer
  include Raylib

  STATE_FILE = File.join(Dir.pwd, '.cache', 'gui_state.json')
  WIN_W = 1200 # Fixed math width for scaling consistency
  WIN_H = 900

  def initialize
    @current_key = nil
    @num_terms = 0
    @last_version = -1
    @terms = []
    
    @offset_x = 50.0
    @offset_y = 450.0
    @zoom_x = 0.5
    @zoom_y = 0.1
    
    @dragging = false
    @last_mouse_x = 0.0

    @sequences = load_sequence_map
    $stdout.sync = true
  end

  # ROBUST CLASS LOADING: Avoids require nil issues
  def load_sequence_map
    map = {}
    Dir.glob(File.join(Dir.pwd, 'sequences', '*.rb')).each do |file|
      key = File.basename(file, '.rb')
      # Camelize key to find class
      class_name = key.split('_').map(&:capitalize).join
      begin
        require file
        map[key] = Object.const_get(class_name)
      rescue => e
        puts "Error loading #{key}: #{e.message}"
      end
    end
    map
  end

  def sync_state
    return unless File.exist?(STATE_FILE)
    
    begin
      state = JSON.parse(File.read(STATE_FILE))
    rescue
      return # File is being written
    end

    return unless state && state['version'].to_i > @last_version
    @last_version = state['version'].to_i

    if state['exit']
      CloseWindow()
      exit(0)
    end
    
    key = state['key'].to_s
    num = state['num_terms'].to_i
    
    klass = @sequences[key]
    if klass
      puts "[Sync] Version #{@last_version}: Loading #{key}..."
      @current_key = key
      @num_terms = num
      @instance = klass.new
      @terms = @instance.generate(@num_terms)
      auto_fit_all()
    end
  end

  def auto_fit_all
    return if @terms.empty?
    
    max_v = @terms.max
    min_v = @terms.min
    range_y = (max_v - min_v).to_f
    range_y = 1.0 if range_y == 0
    
    padding_y = 60.0 
    @zoom_y = (WIN_H - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)

    padding_x = 50.0
    @zoom_x = (WIN_W - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = padding_x
    
    puts "[Scaling] Done. Range: [#{min_v}, #{max_v}], ZoomX: #{@zoom_x.round(2)}"
  end

  def run
    InitWindow(WIN_W, WIN_H, "OEIS Explorer v#{OEIS::VERSION}: Viewer")
    SetTargetFPS(60)

    until WindowShouldClose()
      sync_state()
      update()
      draw()
    end

    CloseWindow()
  end

  def update
    mx = GetMouseX().to_f
    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT); @dragging = true; @last_mouse_x = mx; end
    if IsMouseButtonReleased(MOUSE_BUTTON_LEFT); @dragging = false; end

    if @dragging
      @offset_x += (mx - @last_mouse_x)
      @last_mouse_x = mx
    end

    wheel = GetMouseWheelMove()
    if wheel != 0
      factor = wheel > 0 ? 1.2 : 0.8
      @zoom_x *= factor
    end

    @zoom_x *= 1.02 if IsKeyDown(KEY_D)
    @zoom_x /= 1.02 if IsKeyDown(KEY_A)
    
    auto_fit_all() if IsKeyPressed(KEY_R)
  end

  def draw
    BeginDrawing()
    ClearBackground(RAYWHITE)
    
    # Draw Axes
    DrawLine(0, @offset_y.to_i, WIN_W, @offset_y.to_i, LIGHTGRAY) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, WIN_H, LIGHTGRAY)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < 0 || x1 > WIN_W
        
        y1 = @offset_y - @terms[i - 1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, BLUE)
      end
    end

    name = @instance ? @instance.name : "None"
    DrawRectangle(0, 0, WIN_W, 30, Fade(SKYBLUE, 0.5))
    DrawText("#{name} | Terms: #{@num_terms} | Sync: #{@last_version}", 10, 5, 20, DARKBLUE)

    EndDrawing()
  end
end

if __FILE__ == $0
  RaylibViewer.new.run
end
