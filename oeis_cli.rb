require 'optparse'
require 'prime'
require 'json'
require 'fileutils'
require_relative 'lib/sequence_template'
require_relative 'lib/version'

$stdout.sync = true
puts "OEIS Discovery Framework v#{OEIS::VERSION}"

def load_sequences
  sequences = {}
  Dir.glob(File.join(__dir__, 'sequences', '*.rb')).each do |file|
    key = File.basename(file, '.rb')
    sequences[key] = file
  end
  sequences
end

def load_sequence_class(file)
  existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a
  require File.expand_path(file)
  new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
  key = File.basename(file, '.rb').gsub('_', '')
  klass = new_classes.find { |c| c.to_s.downcase.include?(key) }
  klass || (new_classes - existing_classes).first
end

def build_catalog(sequences, force: false)
  cache_path = '.cache/catalog.json'
  docs_dir = File.join(__dir__, 'docs', 'sequences')
  
  if !force && File.exist?(cache_path)
    cache_time = File.mtime(cache_path)
    needs_update = sequences.values.any? { |f| File.mtime(f) > cache_time }
    return unless needs_update
    puts "[Sync] Updating metadata..."
  end

  FileUtils.mkdir_p(docs_dir)
  FileUtils.mkdir_p('.cache')
  
  catalog_data = []
  sequences.each do |key, file|
    begin
      klass = load_sequence_class(file)
      instance = klass.new
      report = instance.analyze(1000)
      catalog_data << {
        key: key,
        name: instance.name,
        rank: instance.rank,
        formula: instance.formula,
        fitness_score: report[:fitness_score]
      }
    rescue => e
      puts "Error analyzing #{key}: #{e.message}"
    end
  end
  File.write(cache_path, catalog_data.to_json)
end

sequences = load_sequences

OptionParser.new do |opts|
  opts.banner = "Usage: ruby oeis_cli.rb [command]"
  opts.on("-h", "--help") { puts opts; exit }
end.parse!

command = ARGV[0]

case command
when "list"
  sequences.each { |k, _| puts k }
when "build-catalog"
  build_catalog(sequences, force: true)
when "explore"
  build_catalog(sequences)
  
  LOCK_FILE = ".cache/session.lock"
  File.write(LOCK_FILE, Process.pid)
  
  dashboard_path = File.expand_path("lib/visualizers/gui_dashboard.rb", __dir__)
  viewer_path = File.expand_path("lib/visualizers/raylib_viewer.rb", __dir__)
  
  dashboard_cmd = "bundle exec ruby \"#{dashboard_path}\""
  viewer_cmd = "bundle exec ruby \"#{viewer_path}\""
  
  puts "\n🚀 Discovery Station starting! v#{OEIS::VERSION}"
  puts ">> ACTIVE. Close either window to exit."

  pids = []
  begin
    # Spawn sharing console
    pids << Process.spawn(dashboard_cmd, :out => :out, :err => :err)
    pids << Process.spawn(viewer_cmd, :out => :out, :err => :err)
    
    # Wait loop that checks if BOTH are alive
    loop do
      pids.each do |pid|
        if Process.waitpid(pid, Process::WNOHANG)
          puts "Window (PID #{pid}) closed."
          raise Interrupt
        end
      end
      sleep 0.5
    end
  rescue Interrupt
    puts "\nShutting down Discovery Station..."
  ensure
    File.delete(LOCK_FILE) rescue nil
    pids.each do |pid|
      if RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin/
        system("taskkill /F /PID #{pid} /T >NUL 2>&1")
      else
        Process.kill("TERM", pid) rescue nil
      end
    end
    puts "Cleanup complete."
  end
when "analyze"
  key = ARGV[1]
  count = (ARGV[2] || 1000).to_i
  if sequences[key]
    klass = load_sequence_class(sequences[key])
    report = klass.new.analyze(count)
    puts JSON.pretty_generate(report)
  end
else
  puts "Usage: bundle exec ruby oeis_cli.rb explore"
end
