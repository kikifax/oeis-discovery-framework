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

  def initialize
    $stdout.sync = true
    puts ">>> [v1.6.1] LAUNCHING CACHE-BREAKER STATION <<<"
    @sequences = load_catalog
    @current_idx = 0
    @num_terms = 2000
    @input_text = ""
    @edit_mode = false
    @sidebar_tab = :catalog
    @scroll_offset = 0.0
    @dragging = false
    @terms = []
    
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
    @bg_dark      = safe_color(18, 18, 22)
    @sidebar_bg   = safe_color(35, 45, 60) # SLATE BLUE (SYNC PROOF)
    @accent       = safe_color(0, 180, 255)
    @text_main    = safe_color(240, 240, 250)
    @text_dim     = safe_color(140, 150, 170)
    @color_white  = safe_color(255, 255, 255)
    @color_black  = safe_color(0, 0, 0)
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

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)
    begin
      existing = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require File.expand_path(file)
      new_c = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = new_c.find { |c| c.to_s.downcase.include?(key.gsub('_','')) } || (new_c - existing).first
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        @analysis = @instance.analyze(@num_terms) if @instance.respond_to?(:analyze)
        auto_fit_all()
        puts "[v1.6.1] Loaded: #{key}"
        STDOUT.flush
      end
    rescue; end
  end

  def auto_fit_all
    return if @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    max_v, min_v = @terms.max, @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    @zoom_y = (h - 280.0) / range_y
    @offset_y = 120.0 + (max_v * @zoom_y)
    @zoom_x = (w - SIDEBAR_W - 140.0) / [@terms.size.to_f, 1.0].max
    @offset_x = (SIDEBAR_W + 70).to_f
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
        @num_terms = @input_text.to_i if @input_text.to_i > 10
        load_sequence(@sequences[@current_idx][:key]); @edit_mode = false
      elsif IsKeyPressed(KEY_ESCAPE); @edit_mode = false; end
      return
    end

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

    wheel = GetMouseWheelMove()
    if wheel != 0
      if mx < SIDEBAR_W
        @scroll_offset += wheel * 60
        @scroll_offset = [[@scroll_offset, 0.0].min, -(@sequences.size * 35 - 400)].max
      else
        @zoom_x *= (wheel > 0 ? 1.2 : 0.8)
      end
    end
    auto_fit_all() if IsKeyPressed(KEY_R)
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w, h = GetScreenWidth(), GetScreenHeight()

    # GRAPH
    axis_c = safe_color(60,60,75)
    DrawLine(SIDEBAR_W, @offset_y.to_i, w, @offset_y.to_i, axis_c)
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h, axis_c)
    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1 = @offset_x + (i - 1) * @zoom_x; x2 = @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1 = @offset_y - @terms[i-1] * @zoom_y; y2 = @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, @accent)
      end
    end

    # SIDEBAR
    DrawRectangle(0, 0, SIDEBAR_W, h, @sidebar_bg)
    DrawRectangle(SIDEBAR_W - 1, 0, 1, h, safe_color(255,255,255,20))
    draw_text_safe("COMMAND CENTER", 35, 35, 22, @color_white)
    DrawRectangle(35, 68, 80, 4, @accent)

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
    else
      panel_y = 120
      draw_text_safe("REAL-TIME ANALYTICS", 40, panel_y, 16, @accent)
      if @analysis
        stats = [
          "Growth: #{@analysis[:stats][:growth_type]}",
          "Entropy: #{@analysis[:scoring][:activity].round(2)}/25",
          "Novelty: #{@analysis[:scoring][:novelty].round(2)}/25",
          "Diversity: #{@analysis[:scoring][:diversity].round(2)}/25",
          "Score: #{@analysis[:fitness_score]}/100"
        ]
        stats.each_with_index do |txt, i|
          draw_text_safe(txt, 40, panel_y + 50 + (i*35), 18, @color_white)
        end
      end
    end

    DrawRectangle(0, h - 60, SIDEBAR_W, 60, @panel_bg)
    draw_text_safe("CATALOG", 45, h - 35, 18, (@sidebar_tab == :catalog ? @accent : @text_dim))
    draw_text_safe("ANALYTICS", SIDEBAR_W/2 + 30, h - 35, 18, (@sidebar_tab == :analytics ? @accent : @text_dim))

    name = @instance ? @instance.name.upcase : "SELECT"
    @header_pos[:x] = (SIDEBAR_W + 40).to_f
    DrawTextEx(@font, name, @header_pos, 28.0, 1.0, @color_white)
    
    terms_t = "TERMS: #{@edit_mode ? @input_text + '_' : @num_terms}"
    draw_text_safe(terms_t, w - 280, 30, 20, (@edit_mode ? safe_color(255,100,100) : @color_white))

    EndDrawing()
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_MSAA_4X_HINT | FLAG_WINDOW_HIGHDPI)
    InitWindow(1600, 950, "v1.6.1-STATION-SYNC-PROOF")
    SetTargetFPS(60)
    init_theme()
    load_sequence(@sequences[0][:key]) if @sequences.any?
    until WindowShouldClose(); update(); draw(); end
    CloseWindow()
  end
end

RaylibExplorer.new.run
