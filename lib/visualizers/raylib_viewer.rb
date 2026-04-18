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

  SIDEBAR_W = 380

  def initialize
    $stdout.sync = true
    puts ">>> STATION IDENTITY v1.5.14 <<<"
    # Latency buffer
    sleep 0.1
    @sequences = load_catalog
    @current_idx = 0
    @num_terms = 2000
    @input_text = ""
    @edit_mode = false
    @scroll_offset = 0.0
    @dragging = false
    @terms = []
    @offset_x = (SIDEBAR_W + 60).to_f
    @offset_y = 450.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    @vec_tmp = Raylib::Vector2.new
  end

  def safe_color(r, g, b, a=255)
    c = Raylib::Color.new
    c[:r] = r
    c[:g] = g
    c[:b] = b
    c[:a] = a
    c
  end

  def init_theme
    @bg_dark    = safe_color(20, 20, 24)
    @sidebar_bg = Raylib::MAGENTA # FINAL SYNC PROOF
    @accent     = safe_color(0, 180, 255)
    @text_main  = Raylib::WHITE
    @text_dim   = Raylib::LIGHTGRAY
    @color_white = Raylib::WHITE
    @color_black = Raylib::BLACK
    @color_gray  = Raylib::GRAY
    @color_red   = Raylib::RED

    win_f = "C:\\Windows\\Fonts\\arial.ttf"
    if File.exist?(win_f)
      @font = LoadFontEx(win_f, 96, nil, 0)
      if @font && @font.texture.id > 0
        SetTextureFilter(@font.texture, TEXTURE_FILTER_BILINEAR)
      end
    end
    @font ||= GetFontDefault()
  end

  def load_catalog
    cache_p = File.join(Dir.pwd, '.cache', 'catalog.json')
    return [] unless File.exist?(cache_p)
    begin
      data = JSON.parse(File.read(cache_p))
      data.map! do |s|
        { key: s['key'], name: s['name'], score: s['fitness_score'] || 0,
          display: "[#{s['fitness_score'].to_i.to_s.rjust(3)}] #{s['name']}" }
      end
      data.sort_by { |s| -(s[:score] || 0) }
    rescue
      []
    end
  end

  def load_sequence_class(file)
    begin
      existing = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require File.expand_path(file)
      new_c = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      key = File.basename(file, '.rb').gsub('_','')
      klass = new_c.find { |c| c.to_s.downcase.include?(key) }
      klass || (new_c - existing).first
    rescue
      nil
    end
  end

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)
    begin
      klass = load_sequence_class(file)
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        auto_fit_all()
        puts "[Station] Synchronized #{key}"
        STDOUT.flush
      end
    rescue
    end
  end

  def auto_fit_all
    return if @terms.empty?
    w = GetScreenWidth().to_f
    h = GetScreenHeight().to_f
    max_v = @terms.max
    min_v = @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    @zoom_y = (h - 260.0) / range_y
    @offset_y = 110.0 + (max_v * @zoom_y)
    @zoom_x = (w - SIDEBAR_W - 140.0) / [@terms.size.to_f, 1.0].max
    @offset_x = (SIDEBAR_W + 70).to_f
  end

  def draw_text_safe(text, x, y, size, color)
    @vec_tmp[:x] = x.to_f
    @vec_tmp[:y] = y.to_f
    DrawTextEx(@font, text.to_s, @vec_tmp, size.to_f, 1.0, color)
  end

  def update
    if IsKeyPressed(KEY_T)
      @edit_mode = true
      @input_text = ""
      return
    end

    if @edit_mode
      char = GetCharPressed()
      while char > 0
        if (char >= 48) && (char <= 57)
          @input_text << char.chr
        end
        char = GetCharPressed()
      end
      if IsKeyPressed(KEY_BACKSPACE)
        if @input_text.length > 0
          @input_text = @input_text[0...-1]
        end
      end
      if IsKeyPressed(KEY_ENTER)
        if @input_text.to_i > 10
          @num_terms = @input_text.to_i
          load_sequence(@sequences[@current_idx][:key])
        end
        @edit_mode = false
      elsif IsKeyPressed(KEY_ESCAPE)
        @edit_mode = false
      end
      return
    end

    mx = GetMouseX()
    my = GetMouseY()

    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
      if mx < SIDEBAR_W
        list_y = 100.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if my >= list_y && my < list_y + 35
            @current_idx = i
            load_sequence(s[:key])
            break
          end
          list_y += 35
        end
      else
        @dragging = true
        @last_mx = mx.to_f
      end
    elsif IsMouseButtonReleased(MOUSE_BUTTON_LEFT)
      @dragging = false
    end

    if @dragging
      @offset_x += (mx.to_f - @last_mx)
      @last_mx = mx.to_f
    end

    wheel = GetMouseWheelMove()
    if wheel != 0
      if mx < SIDEBAR_W
        @scroll_offset += (wheel * 50)
        if @scroll_offset > 0
          @scroll_offset = 0.0
        end
      else
        if wheel > 0
          @zoom_x *= 1.2
        else
          @zoom_x *= 0.8
        end
      end
    end
    
    if IsKeyPressed(KEY_R)
      auto_fit_all()
    end
    
    if IsKeyPressed(KEY_UP)
      @num_terms += 500
      load_sequence(@sequences[@current_idx][:key])
    elsif IsKeyPressed(KEY_DOWN)
      if @num_terms > 500
        @num_terms -= 500
        load_sequence(@sequences[@current_idx][:key])
      end
    end
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w = GetScreenWidth()
    h = GetScreenHeight()

    DrawLine(SIDEBAR_W, @offset_y.to_i, w, @offset_y.to_i, @color_gray)
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h, @color_gray)

    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x
        x2 = @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1 = @offset_y - @terms[i-1] * @zoom_y
        y2 = @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, @accent)
      end
    end

    DrawRectangle(0, 0, SIDEBAR_W, h, @sidebar_bg)
    draw_text_safe("STATION v1.5.14", 30, 30, 24, @color_black)

    sh = [h - 150, 10].max
    BeginScissorMode(0, 90, SIDEBAR_W, sh.to_i)
      list_y = 100.0 + @scroll_offset
      @sequences.each_with_index do |s, i|
        if i == @current_idx
          DrawRectangle(25, list_y.to_i - 5, SIDEBAR_W - 50, 35, @color_black)
          draw_text_safe(s[:display], 45, list_y.to_i + 4, 18, @color_white)
        else
          draw_text_safe(s[:display], 45, list_y.to_i + 4, 18, @color_black)
        end
        list_y += 35
      end
    EndScissorMode()

    name = @instance ? @instance.name.upcase : "SELECT"
    draw_text_safe(name, SIDEBAR_W + 30, 20, 28, @color_white)
    
    terms_t = "TERMS: #{@edit_mode ? @input_text + '_' : @num_terms}"
    draw_text_safe(terms_t, w - 250, 25, 20, @edit_mode ? @color_red : @color_white)
    EndDrawing()
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_MSAA_4X_HINT)
    InitWindow(1600, 950, "STATION-v1.5.14-SYNCED")
    SetTargetFPS(60)
    init_theme()
    if @sequences.any?
      load_sequence(@sequences[0][:key])
    end
    until WindowShouldClose()
      update()
      draw()
    end
    CloseWindow()
  end
end

RaylibExplorer.new.run
