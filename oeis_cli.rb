require 'optparse'
require 'prime'
require 'json'
require 'fileutils'
require_relative 'lib/version'
require_relative 'lib/sequence_template'

$stdout.sync = true
puts "OEIS Discovery Framework v#{OEIS::VERSION} !!! VISIBILITY V162 !!!"

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
  existing_catalog = File.exist?(cache_path) ? (JSON.parse(File.read(cache_path)) rescue []) : []
  catalog_map = existing_catalog.each_with_object({}) { |s, h| h[s['key']] = s }
  cache_time = File.exist?(cache_path) ? File.mtime(cache_path) : Time.at(0)
  catalog_data = []
  updated = 0
  sequences.sort.each do |key, file|
    cached = catalog_map[key]
    if !force && cached && File.mtime(file) <= cache_time
      catalog_data << cached
    else
      begin
        klass = load_sequence_class(file)
        if klass
          instance = klass.new
          report = instance.analyze(1000)
          catalog_data << { key: key, name: instance.name, rank: instance.rank, formula: instance.formula, fitness_score: report[:fitness_score] }
          updated += 1
        end
      rescue; end
    end
  end
  File.write(cache_path, catalog_data.to_json) if updated > 0 || !File.exist?(cache_path)
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
  # Standardized stable filename
  viewer_path = File.join(__dir__, "lib", "visualizers", "raylib_explorer.rb")
  puts "\n🚀 Launching Obsidian Explorer v#{OEIS::VERSION}..."
  system("bundle exec ruby \"#{viewer_path}\"")
else
  puts "Usage: bundle exec ruby oeis_cli.rb explore"
end
