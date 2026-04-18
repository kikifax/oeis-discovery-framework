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

  SIDEBAR_W = 380.0

  def initialize
    @sequences = load_catalog
    @current_idx = 0
    @num_terms = 2000
    @input_text = ""
    @edit_mode = false
    @scroll_offset = 0.0
    @dragging = false
    @terms = []
    
    @offset_x = SIDEBAR_W + 50.0
    @offset_y = 450.0
    @zoom_x = 1.0
    @zoom_y = 1.0
    
    @text_pos = Raylib::Vector2.new
    @active_font_name = "Default"
    
    $stdout.sync = true
    puts "--- INITIALIZING STATION v1.5.2 ---"
  end

  def init_theme
    # Use built-in constants for sync test
    @bg_dark    = Raylib::DARKGRAY
    @sidebar_bg = Raylib::GOLD # IMPOSSIBLE TO MISS
    @accent     = Raylib::BLUE
    @text_main  = Raylib::WHITE
    @text_dim   = Raylib::LIGHTGRAY
    @panel_bg   = Raylib::BLACK

    # Try to load a massive clean font
    win_font = "C:\\Windows\\Fonts\\segoeui.ttf"
    if File.exist?(win_font)
      @font = LoadFontEx(win_font, 80, nil, 0)
      if @font && @font.texture.id > 0
        SetTextureFilter(@font.texture, TEXTURE_FILTER_BILINEAR)
        @active_font_name = "Segoe UI"
      end
    end
    @font ||= GetFontDefault()
    puts "[Station] Font set to: #{@active_font_name}"
  end

  def load_catalog
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
      data.sort_by { |s| -(s[:score] || 0) }
    rescue; []; end
  end

  def load_sequence(key)
    @current_key = key
    file = File.join(Dir.pwd, 'sequences', "#{key}.rb")
    return unless File.exist?(file)
    begin
      # Manual class lookup to avoid uninitialized constants
      existing = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require File.expand_path(file)
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = new_classes.find { |c| c.to_s.downcase.include?(key.gsub('_', '')) } || (new_classes - existing).first
      
      if klass
        @instance = klass.new
        @terms = @instance.generate(@num_terms)
        root = File.expand_path("../../..", __FILE__)
        doc_path = File.join(root, 'docs', 'sequences', "#{key}.md")
        @doc_lines = File.exist?(doc_path) ? File.read(doc_path).lines.reject{|l| l.start_with?("#", "Doc Version:") || l.strip.empty? }.first(15).map(&:strip) : ["No docs."]
        auto_fit_all()
        puts "[Station] Synchronized #{key}"
      end
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  def auto_fit_all
    return if @terms.empty?
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f
    max_v, min_v = @terms.max, @terms.min
    range_y = [(max_v - min_v).abs, 1.0].max
    @zoom_y = (h - 260.0) / range_y
    @offset_y = 110.0 + (max_v * @zoom_y)
    graph_area_w = w - SIDEBAR_W
    @zoom_x = (graph_area_w - 120.0) / [@terms.size.to_f, 1].max
    @offset_x = SIDEBAR_W + 60.0
  end

  def run
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_MSAA_4X_HINT | FLAG_WINDOW_HIGHDPI)
    InitWindow(1600, 950, "OEIS Station v#{OEIS::VERSION}")
    SetTargetFPS(60)
    init_theme()
    load_sequence(@sequences[0][:key]) if @sequences.any?

    until WindowShouldClose()
      update()
      draw()
    end
    CloseWindow()
  end

  def draw_text_pro(text, x, y, size, color)
    @text_pos[:x], @text_pos[:y] = x.to_f, y.to_f
    # Higher spacing (2.0) to avoid squishing
    DrawTextEx(@font, text.to_s, @text_pos, size.to_f, 2.0, color)
  end

  def update
    # --- KEYBOARD ---
    if IsKeyPressed(KEY_T)
      puts "[DEBUG] T KEY PRESSED"
      @edit_mode = true
      @input_text = ""
    end

    if @edit_mode
      char = GetCharPressed()
      while char > 0
        @input_text << char.chr if (char >= 48) && (char <= 57)
        char = GetCharPressed()
      end
      @input_text = @input_text[0...-1] if IsKeyPressed(KEY_BACKSPACE) && @input_text.length > 0
      if IsKeyPressed(KEY_ENTER)
        puts "[DEBUG] Enter pressed. Setting terms to: #{@input_text}"
        @num_terms = @input_text.to_i if @input_text.to_i > 10
        load_sequence(@sequences[@current_idx][:key])
        @edit_mode = false
      elsif IsKeyPressed(KEY_ESCAPE)
        @edit_mode = false
      end
      return
    end

    # --- MOUSE ---
    mx, my = GetMouseX().to_f, GetMouseY().to_f
    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT)
      if mx < SIDEBAR_W
        list_y = 105.0 + @scroll_offset
        @sequences.each_with_index do |s, i|
          if my >= list_y && my < list_y + 35
            @current_idx = i; load_sequence(s[:key]); break
          end
          list_y += 35
        end
      elsif my < 80 && mx > GetScreenWidth() - 300
        @edit_mode = true; @input_text = ""
      else
        @dragging = true; @last_mouse_x = mx
      end
    elsif IsMouseButtonReleased(MOUSE_BUTTON_LEFT)
      @dragging = false
    end

    if @dragging; @offset_x += (mx - @last_mouse_x); @last_mouse_x = mx; end
    
    wheel = GetMouseWheelMove()
    if wheel != 0
      if mx < SIDEBAR_W
        @scroll_offset += wheel * 50
        @scroll_offset = [@scroll_offset, 0].min
      else
        @zoom_x *= (wheel > 0 ? 1.2 : 0.8)
      end
    end
    
    auto_fit_all() if IsKeyPressed(KEY_R)
  end

  def draw
    BeginDrawing()
    ClearBackground(@bg_dark)
    w, h = GetScreenWidth().to_f, GetScreenHeight().to_f

    # --- GRAPH ---
    DrawLine(SIDEBAR_W.to_i, @offset_y.to_i, w.to_i, @offset_y.to_i, Raylib::GRAY)
    DrawLine(@offset_x.to_i, 0, @offset_x.to_i, h.to_i, Raylib::GRAY)
    if @terms && @terms.size > 1
      (1...@terms.size).each do |i|
        x1, x2 = @offset_x + (i - 1) * @zoom_x, @offset_x + i * @zoom_x
        next if x2 < SIDEBAR_W || x1 > w
        y1, y2 = @offset_y - @terms[i-1] * @zoom_y, @offset_y - @terms[i] * @zoom_y
        DrawLine(x1.to_i, y1.to_i, x2.to_i, y2.to_i, @accent)
      end
    end

    # --- SIDEBAR ---
    DrawRectangle(0, 0, SIDEBAR_W.to_i, h.to_i, @sidebar_bg)
    draw_text_pro("STATION v#{OEIS::VERSION}", 40, 40, 24, Raylib::BLACK)

    BeginScissorMode(0, 95, SIDEBAR_W.to_i, (h - 480).to_i)
      list_y = 105.0 + @scroll_offset
      @sequences.each_with_index do |s, i|
        color = (i == @current_idx) ? Raylib::WHITE : Raylib::BLACK
        if i == @current_idx
          DrawRectangle(25, list_y.to_i - 5, (SIDEBAR_W - 50).to_i, 35, Raylib::BLACK)
        end
        draw_text_pro(s[:display], 45, list_y.to_i + 4, 18, color)
        list_y += 35
      end
    EndScissorMode()

    # Doc panel
    panel_y = h - 350
    DrawRectangle(25, panel_y.to_i, (SIDEBAR_W - 50).to_i, 325, @panel_bg)
    y_ptr = panel_y + 40
    (@doc_lines || []).each do |line|
      draw_text_pro(line[0..35], 45, y_ptr.to_i, 14, @text_dim)
      y_ptr += 20
      break if y_ptr > h - 40
    end

    # --- HEADER ---
    name = @instance ? @instance.name.upcase : "SELECT"
    draw_text_pro(name, SIDEBAR_W.to_i + 40, 25, 26, @text_main)
    
    terms_t = "TERMS: #{@edit_mode ? @input_text + '_' : @num_terms}"
    draw_text_pro(terms_t, w.to_i - 300, 30, 22, @edit_mode ? Raylib::RED : @text_main)

    draw_text_pro("FONT: #{@active_font_name}", w.to_i - 200, h.to_i - 25, 12, Raylib::LIGHTGRAY)

    EndDrawing()
  end
end

RaylibExplorer.new.run
