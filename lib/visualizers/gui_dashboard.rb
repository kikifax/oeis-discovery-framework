require 'glimmer-dsl-libui'
require 'json'
require 'prime'
require_relative '../sequence_template'

class GUIDashboard
  include Glimmer

  STATE_FILE = File.join(Dir.pwd, '.cache', 'gui_state.json')

  def initialize
    FileUtils.mkdir_p(File.dirname(STATE_FILE))
    @sequences = load_all_sequences
    @current_display_name = @sequences.keys.first
    @num_terms = 2000
    save_state
  end

  def load_all_sequences
    cache_path = File.join(Dir.pwd, '.cache', 'catalog.json')
    seqs = {}

    if File.exist?(cache_path)
      puts "Loading sequence metadata from cache..."
      data = JSON.parse(File.read(cache_path))
      data.each do |s|
        display_name = "[#{s['fitness_score'].to_i.to_s.rjust(3)}] #{s['name']}"
        seqs[display_name] = { key: s['key'], score: s['fitness_score'] }
      end
    else
      puts "No metadata cache found. Performing full scan (this may take a while)..."
      Dir.glob(File.join(__dir__, '..', '..', 'sequences', '*.rb')).each do |file|
        existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
        require_relative file
        new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
        klass = (new_classes - existing_classes).first
        
        if klass
          key = File.basename(file, '.rb')
          instance = klass.new
          report = instance.analyze(1000)
          score = report[:fitness_score]
          display_name = "[#{score.to_i.to_s.rjust(3)}] #{instance.name}"
          seqs[display_name] = { key: key, score: score }
        end
      end
    end
    seqs.sort_by { |_, v| -v[:score] }.to_h
  end

  def save_state
    data = @sequences[@current_display_name]
    state = {
      key: data[:key],
      num_terms: @num_terms,
      timestamp: Time.now.to_f
    }
    
    # Robust write to handle temporary Windows file locks
    begin
      File.write(STATE_FILE, state.to_json)
    rescue Errno::EACCES
      # If locked, wait 50ms and try once more
      sleep 0.05
      File.write(STATE_FILE, state.to_json) rescue nil
    end

    update_doc_display(data[:key])
  end

  def update_doc_display(key)
    doc_path = File.join(__dir__, '..', '..', 'docs', 'sequences', "#{key}.md")
    if File.exist?(doc_path)
      content = File.read(doc_path).lines.reject { |l| l.start_with?("Doc Version:") }.join.strip
      @doc_display.text = content if @doc_display
    else
      @doc_display.text = "No documentation found for #{key}.\nRun 'ruby oeis_cli.rb build-catalog' to generate it." if @doc_display
    end
  end

  def delete_current_sequence
    data = @sequences[@current_display_name]
    key = data[:key]
    
    msg = "Are you sure you want to PERMANENTLY delete '#{key}'?\n\nThis will remove:\n- sequences/#{key}.rb\n- docs/sequences/#{key}.md\n- .cache/#{key}.cache"
    
    if confirm("Confirm Deletion", msg)
      # 1. Delete Files
      File.delete(File.join(Dir.pwd, 'sequences', "#{key}.rb")) rescue nil
      File.delete(File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")) rescue nil
      File.delete(File.join(Dir.pwd, '.cache', "#{key}.cache")) rescue nil
      
      # 2. Update metadata cache so it doesn't reappear
      cache_path = File.join(Dir.pwd, '.cache', 'catalog.json')
      if File.exist?(cache_path)
        catalog = JSON.parse(File.read(cache_path))
        catalog.reject! { |s| s['key'] == key }
        File.write(cache_path, catalog.to_json)
      end

      msg_box("Success", "Sequence '#{key}' has been deleted. Please restart the explorer to refresh the list.")
    end
  end

  def launch
    window("OEIS Explorer v#{OEIS::VERSION}: Controls", 400, 800) {
      margined true

      vertical_box {
        group('Sequence Selection') {
          stretchy false
          vertical_box {
            @combo = combobox {
              items @sequences.keys
              selected 0
              on_selected do |c|
                @current_display_name = @sequences.keys[c.selected]
                save_state
              end
            }
            
            horizontal_box {
              stretchy false
              label('Terms to show:')
              entry {
                text @num_terms.to_s
                on_changed do |e|
                  val = e.text.to_i
                  if val > 0
                    @num_terms = val
                    save_state
                  end
                end
              }
              
              button('DELETE') {
                on_clicked { delete_current_sequence }
              }
            }
          }
        }

        group('Documentation & Analysis') {
          @doc_display = non_wrapping_multiline_entry {
            read_only true
          }
        }
        
        label("The Viewer window will update\ninstantly when you change settings.") { stretchy false }
      }
      
      on_closing do
        # On Windows, deleting the file while the Viewer is polling it 
        # causes a Permission Denied error. We'll just leave it.
      end
    }.show
    
    # Set initial doc
    update_doc_display(@sequences[@current_display_name][:key])
  end
end

GUIDashboard.new.launch
