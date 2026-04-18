require 'optparse'
require 'prime'
require 'json'
require 'fileutils'
require_relative 'lib/sequence_template'

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
  require file
  new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
  (new_classes - existing_classes).first
end

def build_catalog(sequences, force: false)
  cache_path = '.cache/catalog.json'
  docs_dir = File.join(__dir__, 'docs', 'sequences')
  if !force && File.exist?(cache_path)
    cache_time = File.mtime(cache_path)
    return if sequences.values.all? { |f| File.mtime(f) <= cache_time }
  end
  FileUtils.mkdir_p(docs_dir)
  FileUtils.mkdir_p('.cache')
  existing_catalog = File.exist?(cache_path) ? (JSON.parse(File.read(cache_path)) rescue []) : []
  catalog_map = existing_catalog.each_with_object({}) { |s, h| h[s['key']] = s }
  catalog_data = []
  sequences.each do |key, file|
    instance = load_sequence_class(file).new
    report = instance.analyze(1000)
    catalog_data << { key: key, name: instance.name, rank: instance.rank, formula: instance.formula, fitness_score: report[:fitness_score] }
  end
  File.write(cache_path, catalog_data.to_json)
  puts "Catalog updated."
end

sequences = load_sequences

OptionParser.new do |opts|
  opts.banner = "Usage: ruby oeis_cli.rb [command]"
  opts.on("-h", "--help") { puts opts; exit }
end.parse!

command = ARGV[0]
key = ARGV[1]
count = (ARGV[2] || 100).to_i

case command
when "list"
  sequences.each { |k, f| puts k }
when "build-catalog"
  build_catalog(sequences, force: true)
when "explore"
  build_catalog(sequences)
  
  # Windows Process Management
  lock_file = ".cache/station.lock"
  File.write(lock_file, Process.pid)
  
  puts "Launching Discovery Station..."
  # 'start' ensures windows actually open and don't block the console
  spawn "bundle exec ruby lib/visualizers/gui_dashboard.rb"
  spawn "bundle exec ruby lib/visualizers/raylib_viewer.rb"
  
  puts ">> ACTIVE. Close the Dashboard window to exit all."
  
  begin
    loop do
      unless File.exist?(lock_file)
        puts "Dashboard closed. Shutting down..."
        break
      end
      sleep 0.5
    end
  rescue Interrupt
    puts "\nInterrupt received."
  ensure
    File.delete(lock_file) rescue nil
    if RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin/
      system("taskkill /F /IM ruby.exe /T >NUL 2>&1")
    end
  end
when "analyze"
  klass = load_sequence_class(sequences[key])
  puts klass.new.analyze(count).to_json if klass
else
  puts "Unknown command."
end
