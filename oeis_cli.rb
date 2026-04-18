require 'optparse'
require 'prime'
require 'json'
require 'fileutils'
require_relative 'lib/version'
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
    puts "[1/2] Detecting changes... Updating cache."
  end

  FileUtils.mkdir_p(docs_dir)
  FileUtils.mkdir_p('.cache')
  
  catalog_data = []
  sequences.each do |key, file|
    puts "Scanning: #{key}..."
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
      puts "Error on #{key}: #{e.message}"
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
  puts "[2/2] Launching Unified Discovery Station..."
  system("bundle exec ruby lib/visualizers/raylib_viewer.rb")
when "analyze"
  key = ARGV[1]
  count = (ARGV[2] || 1000).to_i
  if sequences[key]
    klass = load_sequence_class(sequences[key])
    puts klass.new.analyze(count).to_json
  end
else
  puts "Usage: bundle exec ruby oeis_cli.rb explore"
end
