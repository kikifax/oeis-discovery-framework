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
  FileUtils.mkdir_p('.cache')
  
  # Load existing data to preserve scores for unchanged files
  existing_catalog = File.exist?(cache_path) ? (JSON.parse(File.read(cache_path)) rescue []) : []
  catalog_map = existing_catalog.each_with_object({}) { |s, h| h[s['key']] = s }
  
  cache_time = File.exist?(cache_path) ? File.mtime(cache_path) : Time.at(0)
  catalog_data = []
  updated_count = 0

  sequences.sort.each do |key, file|
    cached = catalog_map[key]
    file_time = File.mtime(file)

    # DIFF SYNC: Only analyze if file is newer than cache OR missing from cache
    if !force && cached && file_time <= cache_time
      catalog_data << cached
    else
      puts "Refreshing: #{key}..."
      begin
        klass = load_sequence_class(file)
        if klass
          instance = klass.new
          report = instance.analyze(1000)
          catalog_data << {
            key: key,
            name: instance.name,
            rank: instance.rank,
            formula: instance.formula,
            fitness_score: report[:fitness_score]
          }
          updated_count += 1
        end
      rescue => e
        puts "Error on #{key}: #{e.message}"
        catalog_data << cached if cached # Fallback to old data on error
      end
    end
  end

  if updated_count > 0 || !File.exist?(cache_path)
    File.write(cache_path, catalog_data.to_json)
    puts "[Sync] Updated #{updated_count} sequences in catalog."
  end
end

sequences = load_sequences

OptionParser.new do |opts|
  opts.banner = "Usage: ruby oeis_cli.rb [command]"
  opts.on("-h", "--help") { puts opts; exit }
end.parse!

command = ARGV[0]

case command
when "explore"
  build_catalog(sequences)
  viewer_path = File.join(__dir__, "lib", "visualizers", "raylib_viewer.rb")
  puts "\n🚀 Launching Explorer Station..."
  system("bundle exec ruby \"#{viewer_path}\"")
when "build-catalog"
  build_catalog(sequences, force: true)
else
  puts "Usage: bundle exec ruby oeis_cli.rb explore"
end
