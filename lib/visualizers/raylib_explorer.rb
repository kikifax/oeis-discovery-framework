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

  SIDEBAR_W = 420
  MAX_INT = 2147483647
  MIN_INT = -2147483648

  def initialize
    $stdout.sync = true
    puts ">>> [v1.8.7] PURE MATH STATION <<<"
    @sequences = load_catalog
    @current_idx = 0
    @num_terms = 2000
    @target_terms = 2000
    @input_text = ""
    @edit_mode = false
    @sidebar_tab = :catalog
    @scroll_offset = 0.0
    @dragging = false
    @terms = []
    @initialized_load = false
    
    @offset_x = (SIDEBAR_W + 80).to_f
    @offset_y = 450.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    
    @vec_tmp = Raylib::Vector2.new
    @header_pos = Raylib::Vector2.new
    @header_pos[:y] = 25.0
  end

  def safe_color(r, g, b, a=255)
    c = Raylib::Color.new
    c[:r], c[:g], c[:b], c[:a] = r, g, b, a
    c
  end

  def init_theme
    @bg_dark    = safe_color(20, 20, 24)
    @sidebar_bg = safe_color(35, 45, 60)
    @accent     = safe_color(0, 180, 255)
    @text_main  = safe_color(240, 240, 250)
    @text_dim   = safe_color(150, 150, 170)
    @color_white = safe_color(255, 255, 255)
    @color_black = safe_color(0, 0, 0)
    @panel_bg     = safe_color(12, 12, 16)

    win_f = "C:\\Windows\\Fonts\\segoeui.ttf"
    if File.exist?(win_f)
      @font = LoadFontEx(win_f, 96, nil, 0)
      SetTextureFilter(@font.texture, TEXTURE_FILTER_BILINEAR) if @font
    end
    @font ||= GetFontDefault()
  end

  def load_catalog
    cache_p = File.join(Dir.pwd, '.cache', 'catalog.json')
    return [] unless File.exist?(cache_p)
    begin
      data = JSON.parse(File.read(cache_p))
      data.map! do |s|
        { 
          key: s['key'], name: s['name'], rank: s['rank'],
          score: s['fitness_score'] || 0,
          display: "[#{s['fitness_score'].to_i}] #{s['name']}"
        }
      end
      data.sort_by { |s| -(s[:score] || 0) }
    rescue; []; end
  end

  def load_sequence(key, target_terms=nil)
    @current_key = key
    @target_terms = target_terms || @num_terms
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)
    begin
      existing = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require File.expand_path(file)
      new_c = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = new_c.find { |c| c.to_s.downcase.include?(key.gsub('_','')) } || (new_c - existing).first
      if klass
        @instance = klass.new
        @terms = [] 
        auto_fit_all(@target_terms)
      end
    rescue; end
  end

  def pump_generation
    return unless @instance
    return if @terms.size >= @target_terms
    
    # Process small chunks for extreme visual feedback
    chunk_size = [(@target_terms * 0.01).to_i, 10].max
    remaining = @target_terms - @terms.size
    chunk_size = remaining if chunk_size > remaining

    @terms = @instance.generate(@terms.size + chunk_size)
    
    # RE-FIT EVERY FRAME while generating to prevent overflow
    auto_fit_all(@target_terms)
  end

  def auto_fit_all(target_count)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    return if w == 0
    if @terms.any?
      max_v, min_v = @terms.max, @terms.min
    else
      max_v, min_v = 1, -1
    end
    range_y = [(max_v - min_v).abs, 1.0].max
    @zoom_y = (h - 280.0) / range_y
    @offset_y = 120.0 + (max_v * @zoom_y)
    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - 140.0) / [target_count.to_f, 1.0].max
    @offset_x = (SIDEBAR_W + 70).to_f
  end

  def safe_i(val)
    val.clamp(MIN_INT, MAX_INT).to_i
  end

  def draw_text_safe(text, x, y, size, color)
    @vec_tmp[:x], @vec_tmp[:y] = x.to_f, y.to_f
    DrawTextEx(@font, text.to_s, @vec_tmp, size.to_f, 0.5, color)
  end

  def update
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    mx, my = GetMouseX(), GetMouseY()

    if IsKeyPressed(KEY_T)
      @edit_mode = true; @input_text = ""; return
    end
    
    if @edit_mode
      char = GetCharPressed()
      while char > 0
        @input_text << char.chr if (char >= 48) && (char <= 57)
        char = GetCharPressed()
      end
      @input_text = @input_text[0...-1] if IsKeyPressed(KEY_BACKSPACE) && @input_text.length > 0
      if IsKeyPressed(KEY_ENTER)
        @num_terms = @input_text.to_i if @input_text.to_i > 5
        load_sequence(@sequences[@current_idx][:key], @num_terms); @edit_mode = false
      elsif IsKeyPressed(KEY_ESCAPE); @edit_mode = false; end
      return
    end

    if !@initialized_load && @sequences.any?
       load_sequence(@sequences[0][:key]); @initialized_load = true
    end

    pump_generation()

    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
      if mx < SIDEBAR_W
        if my > h - 60
          @sidebar_tab = (mx < SIDEBAR_W/2) ? :catalog : :analytics
        elsif @sidebar_tab == :catalog
          list_y = 110.0 + @scroll_offset
          @sequences.each_with_index do |s, i|
            if my >= list_y && my < list_y + 35
              @current_idx = i; load_sequence(s[:key]); break
            end
            list_y += 35
          end
        end
      elsif mx > w - 300 && my < 80
        @edit_mode = true; @input_text = ""
      else
        @dragging = true; @last_mx = mx.to_f
      end
    elsif IsMouseButtonReleased(MOUSE_BUTTON_LEFT); @dragging = false; end

    if @dragging; @offset_x += (mx.to_f - @last_mx); @last_mx = mx.to_f; end
    @zoom_x *= (GetMouseWheelMove() > 0 ? 1.2 : 0.8) if GetMouseWheelMove() != 0
    auto_fit_all(@target_terms) if IsKeyPressed(KEY_R)
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w, h = GetScreenWidth(), GetScreenHeight()

    axis_c = safe_color(60,60,75)
    DrawLine(safe_i(SIDEBAR_W), safe_i(@offset_y), safe_i(w), safe_i(@offset_y), axis_c)
    DrawLine(safe_i(@offset_x), 0, safe_i(@offset_x), safe_i(h), axis_c)
    
    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x; x2 = @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1 = @offset_y - @terms[i-1] * @zoom_y; y2 = @offset_y - @terms[i] * @zoom_y
        DrawLine(safe_i(x1), safe_i(y1), safe_i(x2), safe_i(y2), @accent)
      end
    end

    DrawRectangle(0, 0, SIDEBAR_W, h, @sidebar_bg)
    draw_text_safe("COMMAND CENTER", 35, 35, 22, @color_white)

    if @sidebar_tab == :catalog
      BeginScissorMode(0, 100, SIDEBAR_W, h - 160)
        list_y = 110.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if i == @current_idx
            DrawRectangle(25, list_y.to_i - 5, SIDEBAR_W - 50, 35, @color_black)
            draw_text_safe(s[:display], 45, list_y.to_i + 4, 18, @color_white)
          else
            draw_text_safe(s[:display], 45, list_y.to_i + 4, 18, @text_dim)
          end
          list_y += 35
        end
      EndScissorMode()
    end

    DrawRectangle(0, h - 60, SIDEBAR_W, 60, @panel_bg)
    draw_text_safe("CATALOG", 45, h - 35, 18, (@sidebar_tab == :catalog ? @accent : @color_white))
    draw_text_safe("ANALYTICS", SIDEBAR_W/2 + 30, h - 35, 18, (@sidebar_tab == :analytics ? @accent : @color_white))

    name = @instance ? @instance.name.upcase : "PREPARING..."
    @header_pos[:x] = (SIDEBAR_W + 40).to_f
    DrawTextEx(@font, name, @header_pos, 28.0, 1.0, @color_white)
    prog = (@terms.size.to_f / @target_terms * 100).to_i
    draw_text_safe("TERMS: #{@terms.size} / #{@target_terms} (#{prog}%)", w - 450, 30, 20, (@edit_mode ? safe_color(255,100,100) : @color_white))

    EndDrawing()
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE)
    InitWindow(1600, 950, "OEIS Station v#{OEIS::VERSION}")
    SetTargetFPS(60)
    init_theme()
    until WindowShouldClose(); update(); draw(); end
    CloseWindow()
  end
end

RaylibExplorer.new.run
