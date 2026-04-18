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

include Raylib

class RaylibViewer
  STATE_FILE = File.join(Dir.pwd, '.cache', 'gui_state.json')

  def initialize
    @current_key = nil
    @num_terms = 0
    @last_sync = 0.0
    @terms = []
    
    # View State
    @offset_x = 50.0
    @offset_y = 450.0
    @zoom_x = 0.2
    @zoom_y = 0.01
    
    @dragging = false
    @last_mouse_x = 0.0
    @last_mouse_y = 0.0

    @sequences = load_sequence_map
  end

  def load_sequence_map
    map = {}
    Dir.glob(File.join(__dir__, '..', '..', 'sequences', '**', '*.rb')).each do |file|
      existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require_relative file
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = (new_classes - existing_classes).first
      map[File.basename(file, '.rb')] = klass if klass
    end
    map
  end

  def sync_state
    return unless File.exist?(STATE_FILE)
    
    state = JSON.parse(File.read(STATE_FILE)) rescue nil
    return unless state && state['timestamp'] > @last_sync
    
    puts "Syncing: #{state['key']} (#{state['num_terms']} terms)"
    @last_sync = state['timestamp']
    @num_terms = state['num_terms']
    
    if state['key'] != @current_key || @terms.size != @num_terms
      @current_key = state['key']
      klass = @sequences[@current_key]
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        
        # Auto-fit initially on new sequence
        max_v = @terms.max || 1
        min_v = @terms.min || 0
        range = (max_v - min_v).to_f
        range = 1.0 if range == 0
        @zoom_y = 700.0 / range
        @offset_y = 800.0
      end
    end
  end

  def run
    InitWindow(1200, 900, "OEIS Explorer: Viewer")
    SetTargetFPS(60)

    until WindowShouldClose()
      sync_state # Check for changes from GUI
      update
      draw
    end

    CloseWindow()
  end

  def update
    # Panning
    mouse_x = GetMouseX().to_f
    mouse_y = GetMouseY().to_f
    
    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
      @dragging = true
      @last_mouse_x, @last_mouse_y = mouse_x, mouse_y
    elsif IsMouseButtonReleased(MOUSE_BUTTON_LEFT)
      @dragging = false
    end

    if @dragging
      @offset_x += (mouse_x - @last_mouse_x)
      @offset_y += (mouse_y - @last_mouse_y)
      @last_mouse_x, @last_mouse_y = mouse_x, mouse_y
    end

    # Zooming
    wheel = GetMouseWheelMove()
    if wheel != 0
      factor = wheel > 0 ? 1.2 : 1.0/1.2
      @zoom_x *= factor
      @zoom_y *= factor
    end

    # Scaling
    @zoom_x *= 1.02 if IsKeyDown(KEY_D)
    @zoom_x /= 1.02 if IsKeyDown(KEY_A)
    @zoom_y *= 1.02 if IsKeyDown(KEY_W)
    @zoom_y /= 1.02 if IsKeyDown(KEY_S)
    
    @offset_x, @offset_y = 50.0, 450.0 if IsKeyPressed(KEY_R)
  end

  def draw
    BeginDrawing()
    ClearBackground(RAYWHITE)

    # Draw Axes
    DrawLine(0, @offset_y.to_i, 1200, @offset_y.to_i, LIGHTGRAY) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, 900, LIGHTGRAY)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < 0 || x1 > 1200
        
        y1 = @offset_y - @terms[i - 1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, BLUE)
        DrawCircle(x1.to_i, y1.to_i, 2, MAROON) if @zoom_x > 8.0
      end
    end

    # Overlay
    name = @instance ? @instance.name : "None"
    DrawRectangle(0, 0, 1200, 30, Fade(SKYBLUE, 0.5))
    DrawText("#{name} | Terms: #{@num_terms} | FPS: #{GetFPS()}", 10, 5, 20, DARKBLUE)

    EndDrawing()
  end
end

if __FILE__ == $0
  RaylibViewer.new.run
end
