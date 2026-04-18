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
  key = File.basename(file, '.rb')
  class_name = key.split('_').map(&:capitalize).join
  require file
  Object.const_get(class_name)
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
  
  puts "Updating sequence metadata..."
  catalog_data = []
  sequences.each do |key, file|
    begin
      klass = load_sequence_class(file)
      instance = klass.new
      report = instance.analyze(1000)
      catalog_data << { key: key, name: instance.name, rank: instance.rank, formula: instance.formula, fitness_score: report[:fitness_score] }
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
  sequences.each { |k, f| puts k }
when "build-catalog"
  build_catalog(sequences, force: true)
when "explore"
  build_catalog(sequences)
  
  puts "Launching OEIS Discovery Station v#{OEIS::VERSION}..."
  
  # Using Threads + System is the most reliable way to get output on Windows
  t1 = Thread.new { system("bundle exec ruby lib/visualizers/gui_dashboard.rb") }
  t2 = Thread.new { system("bundle exec ruby lib/visualizers/raylib_viewer.rb") }
  
  puts ">> ACTIVE. Close the Dashboard to exit."
  
  t1.join
  puts "Dashboard closed. Cleaning up..."
  
  if RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin/
    system("taskkill /F /IM ruby.exe /T >NUL 2>&1")
  end
else
  puts "Unknown command."
end
