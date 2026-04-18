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
  lib_file = shared_lib_path + "libraylib.#{arch}.so"
  unless File.exist?(lib_file)
    puts "ERROR: Raylib library not found at #{lib_file}"
    exit(1)
  end
  Raylib.load_lib(lib_file)
end

class RaylibViewer
  STATE_FILE = File.join(Dir.pwd, '.cache', 'gui_state.json')
  
  def initialize
    @current_key = nil
    @num_terms = -1
    @last_version = -1
    @terms = []
    
    # View State
    @offset_x = 0.0
    @offset_y = 0.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    
    @dragging = false
    @last_mouse_x = 0.0

    @sequences = load_sequence_map
    $stdout.sync = true
  end

  def load_sequence_class(file)
    existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
    require file
    new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
    (new_classes - existing_classes).first
  end

  def load_sequence_map
    map = {}
    Dir.glob(File.join(Dir.pwd, 'sequences', '*.rb')).each do |file|
      key = File.basename(file, '.rb')
      klass = load_sequence_class(file)
      map[key] = klass if klass
    end
    map
  end

  def sync_state
    return unless File.exist?(STATE_FILE)
    begin
      state = JSON.parse(File.read(STATE_FILE))
    rescue
      return
    end

    # Sync by version
    new_v = state['version'].to_i
    return if new_v <= @last_version
    @last_version = new_v

    if state['exit']
      Raylib.CloseWindow()
      exit(0)
    end
    
    key = state['key'].to_s
    num = state['num_terms'].to_i
    
    klass = @sequences[key]
    if klass
      puts "[Sync] v#{@last_version}: #{key}"
      @current_key = key
      @num_terms = num
      @instance = klass.new
      @terms = @instance.generate(@num_terms)
      auto_fit_all()
    end
  end

  def auto_fit_all
    return if @terms.empty?
    
    w = Raylib.GetScreenWidth().to_f
    h = Raylib.GetScreenHeight().to_f
    
    max_v = @terms.max
    min_v = @terms.min
    range_y = (max_v - min_v).to_f
    range_y = 1.0 if range_y == 0
    
    padding_y = 100.0 
    @zoom_y = (h - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)

    padding_x = 60.0
    @zoom_x = (w - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = padding_x
  end

  def auto_fit_y_visible
    return if @terms.nil? || @terms.empty?
    w = Raylib.GetScreenWidth().to_f
    h = Raylib.GetScreenHeight().to_f
    
    start_i = [((- @offset_x) / @zoom_x).floor, 0].max
    end_i = [((w - @offset_x) / @zoom_x).ceil, @terms.size - 1].min
    return if start_i >= @terms.size || end_i < 0 || start_i >= end_i
    
    slice = @terms[start_i..end_i]
    return if slice.nil? || slice.empty?
    
    range_y = (slice.max - slice.min).to_f
    range_y = 1.0 if range_y == 0
    
    padding_y = 100.0 
    @zoom_y = (h - padding_y * 2) / range_y
    @offset_y = padding_y + (slice.max * @zoom_y)
  end

  def run
    Raylib.InitWindow(1600, 950, "OEIS Explorer v#{OEIS::VERSION}: Viewer")
    Raylib.SetTargetFPS(60)

    until Raylib.WindowShouldClose()
      sync_state()
      auto_fit_y_visible() unless Raylib.IsMouseButtonDown(Raylib::MOUSE_BUTTON_LEFT) || Raylib.GetMouseWheelMove() != 0
      update()
      draw()
    end
    Raylib.CloseWindow()
  end

  def update
    mx = Raylib.GetMouseX().to_f
    if Raylib.IsMouseButtonPressed(Raylib::MOUSE_BUTTON_LEFT); @dragging = true; @last_mouse_x = mx; end
    if Raylib.IsMouseButtonReleased(Raylib::MOUSE_BUTTON_LEFT); @dragging = false; end

    if @dragging
      @offset_x += (mx - @last_mouse_x)
      @last_mouse_x = mx
    end

    wheel = Raylib.GetMouseWheelMove()
    @zoom_x *= (wheel > 0 ? 1.2 : 0.8) if wheel != 0
    auto_fit_all() if Raylib.IsKeyPressed(Raylib::KEY_R)
  end

  def draw
    Raylib.BeginDrawing()
    Raylib.ClearBackground(Raylib::RAYWHITE)
    
    w = Raylib.GetScreenWidth().to_f
    h = Raylib.GetScreenHeight().to_f

    # Grid
    Raylib.DrawLine(0, @offset_y.to_i, w.to_i, @offset_y.to_i, Raylib::LIGHTGRAY) 
    Raylib.DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, Raylib::LIGHTGRAY)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < 0 || x1 > w
        
        y1 = @offset_y - @terms[i - 1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        
        Raylib.DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, Raylib::BLUE)
      end
    end

    # Status Bar
    Raylib.DrawRectangle(0, 0, w.to_i, 35, Raylib.Fade(Raylib::SKYBLUE, 0.5))
    name = @instance ? @instance.name : "None"
    Raylib.DrawText("#{name} | Terms: #{@num_terms}", 15, 8, 20, Raylib::DARKBLUE)

    Raylib.EndDrawing()
  end
end

if __FILE__ == $0
  RaylibViewer.new.run
end
