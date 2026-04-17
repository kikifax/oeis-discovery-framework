require 'glimmer-dsl-libui'
require 'prime'
require_relative '../sequence_template'

class OEISExplorer
  include Glimmer

  def initialize
    @sequences = load_all_sequences
    @current_display_name = @sequences.keys.first
    @num_terms = 2000
    
    @zoom_x = 1.0
    @zoom_y = 1.0
    @offset_x = 0
    @offset_y = 0
    @last_w = 0
    @last_h = 0
    @user_transformed = false
    @dragging = false

    update_sequence(@current_display_name)
  end

  def load_all_sequences
    seqs = {}
    # Scan all sequences in the sequences/ directory
    Dir.glob(File.join(__dir__, '..', '..', 'sequences', '**', '*.rb')).each do |file|
      # Use a clean way to load the class
      existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
      require_relative file
      new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
      klass = (new_classes - existing_classes).first
      
      if klass
        key = File.basename(file, '.rb')
        instance = klass.new
        # Get score for sorting (using cache if exists)
        report = instance.analyze(1000)
        score = report[:fitness_score]
        
        # Store metadata for the dropdown
        display_name = "[#{score.to_i.to_s.rjust(3)}] #{instance.name}"
        seqs[display_name] = { key: key, klass: klass, score: score }
      end
    end
    # Sort by score descending
    seqs.sort_by { |_, v| -v[:score] }.to_h
  end

  def update_sequence(display_name)
    @current_display_name = display_name
    data = @sequences[display_name]
    @instance = data[:klass].new
    @terms = @instance.generate(@num_terms)
    @user_transformed = false # Reset view for new sequence
    
    # Load Documentation
    doc_path = File.join(__dir__, '..', '..', 'docs', 'sequences', "#{data[:key]}.md")
    if File.exist?(doc_path)
      # Strip the Doc Version header for the UI
      content = File.read(doc_path).lines.reject { |l| l.start_with?("Doc Version:") }.join.strip
      @doc_display.text = content if @doc_display
    else
      @doc_display.text = "No documentation found for #{key}.\nRun 'ruby oeis_cli.rb build-catalog' to generate it." if @doc_display
    end

    @area.queue_redraw_all if @area
  end

  def fit_to_area(width, height)
    return if width <= 0 || height <= 0 || @terms.empty?
    
    max_val = @terms.max
    min_val = @terms.min
    
    view_max = [max_val, 0].max
    view_min = [min_val, 0].min
    range_y = (view_max - view_min).to_f
    range_y = 1.0 if range_y == 0
    
    padding_x = 0.05
    padding_y = 0.15
    
    draw_w = width * (1.0 - padding_x * 2)
    draw_h = height * (1.0 - padding_y * 2)

    @zoom_x = draw_w / [@terms.size, 1].max
    @zoom_y = draw_h / range_y
    
    @offset_x = width * padding_x
    @offset_y = (height * padding_y) + (view_max * @zoom_y)
    
    @last_w = width
    @last_h = height
  end

  def launch
    window('OEIS Sequence Explorer', 1400, 900) {
      margined true

      horizontal_box {
        # LEFT PANEL: Controls
        vertical_box {
          stretchy false
          
          group('Sequence Selection') {
            stretchy false
            vertical_box {
              label('Choose Sequence:')
              @seq_combo = combobox {
                items @sequences.keys
                selected 0
                on_selected do |c|
                  update_sequence(@sequences.keys[c.selected])
                end
              }
              
              label('Terms to Generate:')
              @terms_entry = entry {
                text @num_terms.to_s
                on_changed do |e|
                  val = e.text.to_i
                  if val > 0
                    @num_terms = val
                    update_sequence(@current_display_name)
                  end
                end
              }
            }
          }

          group('Documentation & Analysis') {
            vertical_box {
              @doc_display = non_wrapping_multiline_entry {
                read_only true
                text "Loading documentation..."
              }
            }
          }

          group('View Controls') {
            stretchy false
            vertical_box {
              button('Fit to View') { on_clicked { @user_transformed = false; @area.queue_redraw_all } }
              
              horizontal_box {
                button('Zoom In') { on_clicked { @user_transformed = true; @zoom_x *= 1.4; @zoom_y *= 1.4; @area.queue_redraw_all } }
                button('Zoom Out') { on_clicked { @user_transformed = true; @zoom_x /= 1.4; @zoom_y /= 1.4; @area.queue_redraw_all } }
              }
              
              horizontal_box {
                button('Stretch Y') { on_clicked { @user_transformed = true; @zoom_y *= 1.2; @area.queue_redraw_all } }
                button('Shrink Y') { on_clicked { @user_transformed = true; @zoom_y /= 1.2; @area.queue_redraw_all } }
              }
            }
          }
          
          label("Left-click and drag to pan.\nZoom controls center on origin.") { stretchy false }
        }

        # RIGHT PANEL: Visualization
        @area = area {
          on_draw do |area_draw_params|
            w = area_draw_params[:area_width]
            h = area_draw_params[:area_height]
            
            if (@last_w != w || @last_h != h) && !@user_transformed
              fit_to_area(w, h)
            end

            # Background
            path {
              rectangle(0, 0, w, h)
              fill 0xFA, 0xFA, 0xFA
            }

            # 1. Draw Axes (Red)
            path {
              line(@offset_x, 0, @offset_x, h) # Vertical
              line(0, @offset_y, w, @offset_y) # Horizontal
              stroke :red, thickness: 1
            }

            # 2. Draw Continuous Path (Blue)
            path {
              if @terms.any?
                figure(@offset_x, @offset_y - (@terms[0] * @zoom_y)) {
                  @terms[1..-1].each_with_index do |val, i|
                    idx = i + 1
                    line(@offset_x + (idx * @zoom_x), @offset_y - (val * @zoom_y))
                  end
                }
              end
              stroke 0x21, 0x96, 0xF3, thickness: 1.5 # Material Blue
            }
            
            # 3. Draw Points (Only when zoomed in)
            if @zoom_x > 4.0
              @terms.each_with_index do |val, i|
                x = @offset_x + (i * @zoom_x)
                y = @offset_y - (val * @zoom_y)
                path {
                  figure(x, y) { arc(x, y, 2.0, 0, 2 * Math::PI, false) }
                  fill 0xE9, 0x1E, 0x63 # Material Pink
                }
              end
            end
          end

          on_mouse_down do |e|
            @dragging = true
            @user_transformed = true
            @last_x, @last_y = e[:x], e[:y]
          end

          on_mouse_up { @dragging = false }

          on_mouse_dragged do |e|
            if @dragging
              @offset_x += (e[:x] - @last_x)
              @offset_y += (e[:y] - @last_y)
              @last_x, @last_y = e[:x], e[:y]
              @area.queue_redraw_all
            end
          end
        }
      }
    }.show
  end
end

OEISExplorer.new.launch
