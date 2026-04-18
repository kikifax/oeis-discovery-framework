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
  WIN_W = 1600
  WIN_H = 900

  def initialize
    @current_key = nil
    @num_terms = 0
    @last_sync = 0.0
    @terms = []
    
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
    Dir.glob(File.join(__dir__, '..', '..', 'sequences', '*.rb')).each do |file|
      existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require file
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = (new_classes - existing_classes).first
      map[File.basename(file, '.rb')] = klass if klass
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

    return unless state && state['timestamp'] > @last_sync
    
    # Update Sync Timestamp
    @last_sync = state['timestamp']

    if state['exit']
      CloseWindow()
      exit(0)
    end
    
    # If key OR term count changed, we need a hard re-fit
    if state['key'] != @current_key || state['num_terms'] != @num_terms
      puts "Re-Scaling: #{state['key']} for #{state['num_terms']} terms..."
      @current_key = state['key']
      @num_terms = state['num_terms']
      
      klass = @sequences[@current_key]
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        auto_fit_all()
      end
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    
    # 1. Y-Fit (Full range)
    max_v = @terms.max
    min_v = @terms.min
    range_y = (max_v - min_v).to_f
    range_y = 1.0 if range_y == 0
    padding_y = 60.0 
    @zoom_y = (WIN_H - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)

    # 2. X-Fit (Full length)
    padding_x = 50.0
    @zoom_x = (WIN_W - padding_x * 2) / [@terms.size.to_f, 1].max
    @offset_x = padding_x
    
    puts "View Synced. ZoomX: #{@zoom_x.round(4)}, OffsetX: #{@offset_x}"
  end

  def auto_fit_y_visible
    return if @terms.nil? || @terms.empty?
    
    # Find start and end index visible in the window (accounting for sidebar area if any)
    start_i = [((- @offset_x) / @zoom_x).floor, 0].max
    end_i = [((WIN_W - @offset_x) / @zoom_x).ceil, @terms.size - 1].min
    
    return if start_i >= @terms.size || end_i < 0 || start_i >= end_i
    
    visible_slice = @terms[start_i..end_i]
    return if visible_slice.nil? || visible_slice.empty?
    
    max_v = visible_slice.max
    min_v = visible_slice.min
    range_y = (max_v - min_v).to_f
    range_y = 1.0 if range_y == 0
    
    padding_y = 60.0 
    @zoom_y = (WIN_H - padding_y * 2) / range_y
    @offset_y = padding_y + (max_v * @zoom_y)
  end

  def run
    InitWindow(WIN_W, WIN_H, "OEIS Explorer v#{OEIS::VERSION}: Viewer")
    SetTargetFPS(60)

    until WindowShouldClose()
      sync_state()
      # Only auto-scale Y visible if we are NOT dragging or zooming
      auto_fit_y_visible() unless IsMouseButtonDown(MOUSE_BUTTON_LEFT) || GetMouseWheelMove() != 0
      update()
      draw()
    end

    CloseWindow()
  end

  def update
    mx = GetMouseX().to_f
    
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
    if wheel != 0
      factor = wheel > 0 ? 1.2 : 1.0/1.2
      @zoom_x *= factor
    end

    @zoom_x *= 1.02 if IsKeyDown(KEY_D)
    @zoom_x /= 1.02 if IsKeyDown(KEY_A)
    
    if IsKeyPressed(KEY_R)
      auto_fit_all()
    end
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
        if @zoom_x > 8.0
          DrawCircle(x1.to_i, y1.to_i, 2, MAROON)
        end
      end
    end

    name = @instance ? @instance.name : "None"
    DrawRectangle(0, 0, WIN_W, 30, Fade(SKYBLUE, 0.5))
    DrawText("#{name} | Terms: #{@num_terms} | FPS: #{GetFPS()}", 10, 5, 20, DARKBLUE)

    EndDrawing()
  end
end

if __FILE__ == $0
  RaylibViewer.new.run
end
