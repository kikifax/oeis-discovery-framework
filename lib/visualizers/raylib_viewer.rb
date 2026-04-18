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
  LOCK_FILE = File.join(Dir.pwd, '.cache', 'session.lock')
  
  W = 1600.0
  H = 900.0

  def initialize
    @current_key = nil
    @num_terms = 0
    @last_version = -1
    @terms = []
    @status = "Waiting for Dashboard..."
    
    @offset_x = 0.0
    @offset_y = 0.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    
    @dragging = false
    @last_mouse_x = 0.0

    @sequences = load_sequence_map
    $stdout.sync = true
    puts "[VIEWER] Initialized v#{OEIS::VERSION}"
  end

  def load_sequence_map
    map = {}
    Dir.glob(File.join(Dir.pwd, 'sequences', '*.rb')).each do |file|
      key = File.basename(file, '.rb')
      class_name = key.split('_').map(&:capitalize).join
      begin
        require file
        map[key] = Object.const_get(class_name) rescue nil
      rescue
      end
    end
    map
  end

  def watchdog
    unless File.exist?(LOCK_FILE)
      CloseWindow()
      exit(0)
    end
  end

  def sync_state
    watchdog()
    return unless File.exist?(STATE_FILE)
    
    begin
      raw = File.read(STATE_FILE)
      return if raw.nil? || raw.empty?
      state = JSON.parse(raw)
    rescue
      return
    end

    # SYNC BY VERSION
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
      puts "[VIEWER] Syncing Data: #{key} (#{num} terms) | v#{@last_version}"
      @current_key = key
      @num_terms = num
      @instance = klass.new
      @terms = @instance.generate(@num_terms)
      auto_fit_all()
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    
    max_v = @terms.max
    min_v = @terms.min
    range_y = (max_v - min_v).to_f
    range_y = 1.0 if range_y == 0
    
    padding_y = 100.0 
    @zoom_y = (H - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)

    padding_x = 60.0
    @zoom_x = (W - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = padding_x
    
    @status = "Synced & Fit (v#{@last_version})"
    puts "[VIEWER] Auto-Fit Done. ZoomX: #{@zoom_x.round(4)}"
  end

  def auto_fit_y_visible
    return if @terms.nil? || @terms.empty?
    
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    
    start_i = [((- @offset_x) / @zoom_x).floor, 0].max
    end_i = [((w - @offset_x) / @zoom_x).ceil, @terms.size - 1].min
    
    return if start_i >= @terms.size || end_i < 0 || start_i >= end_i
    
    slice = @terms[start_i..end_i]
    return if slice.nil? || slice.empty?
    
    max_v = slice.max
    min_v = slice.min
    range_y = (max_v - min_v).to_f
    range_y = 1.0 if range_y == 0
    
    padding_y = 100.0 
    @zoom_y = (h - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)
  end

  def run
    InitWindow(1600, 900, "OEIS Explorer v#{OEIS::VERSION}: Viewer")
    SetTargetFPS(60)

    until WindowShouldClose()
      sync_state()
      # Only dynamic Y-scale if NOT dragging
      auto_fit_y_visible() unless IsMouseButtonDown(MOUSE_BUTTON_LEFT) || GetMouseWheelMove() != 0
      
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
    
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # Draw Axes
    DrawLine(0, @offset_y.to_i, w.to_i, @offset_y.to_i, LIGHTGRAY) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, LIGHTGRAY)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < 0 || x1 > w
        
        y1 = @offset_y - @terms[i - 1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, BLUE)
        if @zoom_x > 8.0
          DrawCircle(x1.to_i, y1.to_i, 2, MAROON)
        end
      end
    end

    # Overlay
    name = @instance ? @instance.name : "Waiting..."
    DrawRectangle(0, 0, w.to_i, 35, Fade(SKYBLUE, 0.8))
    DrawText("#{name} | Terms: #{@num_terms} | Sync: v#{@last_version}", 15, 8, 20, DARKBLUE)

    EndDrawing()
  end
end

if __FILE__ == $0
  RaylibViewer.new.run
end
