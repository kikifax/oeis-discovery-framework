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
  
  viewer_path = File.join(__dir__, "lib", "visualizers", "raylib_viewer.rb")
  viewer_cmd = "bundle exec ruby \"#{viewer_path}\""
  
  puts "\n🚀 Launching Unified Discovery Station v#{OEIS::VERSION}..."
  
  begin
    # Launch only the unified viewer
    system(viewer_cmd)
  rescue Interrupt
    puts "\nShutting down..."
  ensure
    if RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin/
      system("taskkill /F /IM ruby.exe /T >NUL 2>&1")
    end
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
