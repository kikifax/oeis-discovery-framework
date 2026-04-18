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
  
  W = 1600
  H = 900

  def initialize
    @current_key = nil
    @num_terms = 0
    @last_version = -1
    @terms = []
    @status = "Ready"
    @loaded_classes = {} # Lazy cache
    
    @offset_x = 0.0
    @offset_y = 0.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    @dragging = false
    
    $stdout.sync = true
    puts "[VIEWER] Station v#{OEIS::VERSION} Online (Lazy Mode)."
  end

  def load_class_on_demand(key)
    return @loaded_classes[key] if @loaded_classes[key]
    
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return nil unless File.exist?(file)

    puts "[VIEWER] Loading sequence: #{key}..."
    existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
    begin
      require file
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = new_classes.find { |c| c.to_s.downcase.include?(key.gsub('_', '')) }
      klass ||= (new_classes - existing_classes).first
      @loaded_classes[key] = klass
    rescue => e
      puts "[VIEWER] Error loading #{key}: #{e.message}"
      nil
    end
  end

  def watchdog
    unless File.exist?(LOCK_FILE); CloseWindow(); exit(0); end
  end

  def sync_state
    watchdog()
    return unless File.exist?(STATE_FILE)
    
    begin
      raw = File.read(STATE_FILE)
      return if raw.nil? || raw.empty?
      state = JSON.parse(raw)
    rescue; return; end

    return unless state && state['version'].to_i > @last_version
    @last_version = state['version'].to_i

    if state['exit']; CloseWindow(); exit(0); end
    
    key = state['key'].to_s
    num = state['num_terms'].to_i
    
    if key == @current_key && @instance
      @num_terms = num
      @terms = @instance.generate(@num_terms)
      auto_fit_all()
    else
      klass = load_class_on_demand(key)
      if klass
        @current_key = key
        @num_terms = num
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        auto_fit_all()
      end
    end
  end

  def auto_fit_all
    return if @terms.nil? || @terms.empty?
    max_v, min_v = @terms.max, @terms.min
    range_y = [max_v - min_v, 1.0].max
    
    @zoom_y = (H - 200.0) / range_y
    @offset_y = 100.0 + (max_v * @zoom_y)

    @zoom_x = (W - 100.0) / [@terms.size.to_f, 1].max
    @offset_x = 50.0
    @status = "Fit Done"
  end

  def auto_fit_y_visible
    return if @terms.nil? || @terms.empty?
    start_i = [((- @offset_x) / @zoom_x).floor, 0].max
    end_i = [((W - @offset_x) / @zoom_x).ceil, @terms.size - 1].min
    return if start_i >= @terms.size || end_i < 0 || start_i >= end_i
    
    slice = @terms[start_i..end_i]
    return if slice.nil? || slice.empty?
    
    max_v, min_v = slice.max, slice.min
    range_y = [max_v - min_v, 1.0].max
    @zoom_y = (H - 200.0) / range_y
    @offset_y = 100.0 + (max_v * @zoom_y)
  end

  def run
    InitWindow(W, H, "OEIS Discovery Viewer v#{OEIS::VERSION}")
    SetTargetFPS(60)
    until WindowShouldClose()
      sync_state()
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
    if wheel != 0; @zoom_x *= (wheel > 0 ? 1.2 : 0.8); end
    auto_fit_all() if IsKeyPressed(KEY_R)
  end

  def draw
    BeginDrawing()
    ClearBackground(RAYWHITE)
    DrawLine(0, @offset_y.to_i, W, @offset_y.to_i, LIGHTGRAY) 
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, H, LIGHTGRAY)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1, x2 = @offset_x + (i - 1) * @zoom_x, @offset_x + i * @zoom_x
        next if x2 < 0 || x1 > W
        y1, y2 = @offset_y - @terms[i - 1] * @zoom_y, @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, BLUE)
      end
    end

    DrawRectangle(0, 0, W, 35, Fade(SKYBLUE, 0.8))
    DrawText("#{@current_key} | #{@status} | v#{@last_version}", 15, 8, 20, DARKBLUE)
    EndDrawing()
  end
end

RaylibViewer.new.run
