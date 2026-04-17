require 'glimmer-dsl-libui'
require 'prime'

# Load the user's sequence and optional term count
if ARGV.empty?
  puts "Usage: ruby oeis_gui.rb <sequence_file.rb> [num_terms]"
  exit
end

require_relative ARGV[0].sub(".rb", "")
seq_class = ObjectSpace.each_object(Class).find { |c| c < OEISSequence }
unless seq_class
  puts "No OEISSequence class found!"
  exit
end

NUM_TERMS = (ARGV[1] || 2000).to_i

class OEISExplorer
  include Glimmer

  def initialize(sequence, term_count)
    @sequence = sequence
    print "Generating #{term_count} terms..."
    @terms = @sequence.generate(term_count)
    puts " Done."
    
    @zoom_x = 1.0
    @zoom_y = 1.0
    @offset_x = 0
    @offset_y = 0
    @last_w = 0
    @last_h = 0
    @user_transformed = false

    @dragging = false
  end

  # Calculate scaling to fit the data perfectly within the current area
  def fit_to_area(width, height)
    return if width <= 0 || height <= 0
    
    max_val = @terms.max || 1
    min_val = @terms.min || 0
    
    # We always want to see the X-axis (0) as a reference
    view_max = [max_val, 0].max
    view_min = [min_val, 0].min
    range_y = (view_max - view_min).to_f
    range_y = 1.0 if range_y == 0
    
    # Increased padding (15%) to ensure clear visibility above buttons and labels
    padding_x = 0.05
    padding_y = 0.15
    
    draw_w = width * (1.0 - padding_x * 2)
    draw_h = height * (1.0 - padding_y * 2)

    @zoom_x = draw_w / [@terms.size, 1].max
    @zoom_y = draw_h / range_y
    
    @offset_x = width * padding_x
    # The X-axis (y=0) pixel position:
    # Top padding + (distance from view_max to 0 in pixels)
    @offset_y = (height * padding_y) + (view_max * @zoom_y)
    
    @last_w = width
    @last_h = height
  end

  def launch
    window('OEIS Explorer: ' + @sequence.name, 1200, 800) {
      margined true

      vertical_box {
        label("Sequence: #{@sequence.description}") { stretchy false }

        @area = area {
          on_draw do |area_draw_params|
            w = area_draw_params[:area_width]
            h = area_draw_params[:area_height]
            
            # Auto-refit if window resized OR if we haven't initialized yet
            if (@last_w != w || @last_h != h) && !@user_transformed
              fit_to_area(w, h)
            end

            # Background
            path {
              rectangle(0, 0, w, h)
              fill 0xFA, 0xFA, 0xFA
            }

            # 1. Draw Axes (Red) - Thicker for clarity
            path {
              # Vertical Axis (Y)
              line(@offset_x, 0, @offset_x, h)
              # Horizontal Axis (X)
              line(0, @offset_y, w, @offset_y)
              stroke :red, thickness: 2
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
              stroke :blue, thickness: 1.5
            }
            
            # 3. Draw Points (Only when zoomed in)
            if @zoom_x > 5.0
              @terms.each_with_index do |val, i|
                x = @offset_x + (i * @zoom_x)
                y = @offset_y - (val * @zoom_y)
                path {
                  figure(x, y) { arc(x, y, 2.5, 0, 2 * Math::PI, false) }
                  fill :maroon
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
        
        horizontal_box {
          stretchy false
          button('Zoom In') { on_clicked { @user_transformed = true; @zoom_x *= 1.4; @zoom_y *= 1.4; @area.queue_redraw_all } }
          button('Zoom Out') { on_clicked { @user_transformed = true; @zoom_x /= 1.4; @zoom_y /= 1.4; @area.queue_redraw_all } }
          button('Stretch Y') { on_clicked { @user_transformed = true; @zoom_y *= 1.2; @area.queue_redraw_all } }
          button('Reset View') { on_clicked { @user_transformed = false; @area.queue_redraw_all } }
        }
      }
    }.show
  end
end

OEISExplorer.new(seq_class.new, NUM_TERMS).launch
