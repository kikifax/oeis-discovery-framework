require 'glimmer-dsl-libui'
require 'json'
require 'prime'
require 'fileutils'
require_relative '../sequence_template'

class GUIDashboard
  include Glimmer

  STATE_FILE = File.join(Dir.pwd, '.cache', 'gui_state.json')

  def initialize
    FileUtils.mkdir_p(File.dirname(STATE_FILE))
    @sequences = load_all_sequences
    @current_display_name = @sequences.keys.first
    @num_terms = 2000
    @state_version = 1
    save_state
  end

  def load_all_sequences
    cache_path = File.join(Dir.pwd, '.cache', 'catalog.json')
    seqs = {}
    if File.exist?(cache_path)
      data = JSON.parse(File.read(cache_path))
      data.each do |s|
        display_name = "[#{s['fitness_score'].to_i.to_s.rjust(3)}] #{s['name']}"
        seqs[display_name] = { key: s['key'], score: s['fitness_score'] }
      end
    end
    seqs.sort_by { |_, v| -v[:score] }.to_h
  end

  def save_state
    @state_version += 1
    data = @sequences[@current_display_name]
    return unless data
    
    state = {
      key: data[:key],
      num_terms: @num_terms,
      version: @state_version,
      timestamp: Time.now.to_f
    }
    
    begin
      File.write(STATE_FILE, state.to_json)
    rescue
      # Silent fail for lock
    end
    update_doc_display(data[:key])
  end

  def update_doc_display(key)
    doc_path = File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")
    if File.exist?(doc_path)
      content = File.read(doc_path).lines.reject { |l| l.start_with?("Doc Version:") }.join.strip
      @doc_display.text = content if @doc_display
    end
  end

  def delete_current_sequence
    data = @sequences[@current_display_name]
    key = data[:key]
    msg = "PERMANENTLY delete '#{key}'?\n\n- sequences/#{key}.rb\n- docs/sequences/#{key}.md\n- .cache/#{key}.cache"
    
    if confirm("Confirm", msg)
      File.delete(File.join(Dir.pwd, 'sequences', "#{key}.rb")) rescue nil
      File.delete(File.join(Dir.pwd, 'docs', 'sequences', "#{key}.md")) rescue nil
      File.delete(File.join(Dir.pwd, '.cache', "#{key}.cache")) rescue nil
      msg_box("Deleted", "Please restart the station.")
    end
  end

  def launch
    window("OEIS Explorer v#{OEIS::VERSION}: Controls", 450, 800) {
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
              label('Terms:') { stretchy false }
              entry {
                text @num_terms.to_s
                on_changed do |e|
                  @num_terms = e.text.to_i if e.text.to_i > 0
                  save_state
                end
              }
              
              button('RESCALE') {
                on_clicked { save_state }
              }
            }
            
            button('DELETE THIS SEQUENCE') {
              on_clicked { delete_current_sequence }
            }
          }
        }

        group('Analysis') {
          @doc_display = non_wrapping_multiline_entry { read_only true }
        }
      }
      
      on_closing do
        File.delete(".cache/station.lock") rescue nil
        File.write(STATE_FILE, {exit: true, timestamp: Time.now.to_f}.to_json) rescue nil
      end
    }.show
    update_doc_display(@sequences[@current_display_name][:key])
  end
end

GUIDashboard.new.launch
