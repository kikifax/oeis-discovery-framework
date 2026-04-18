require 'optparse'
require 'prime'
require 'json'
require 'fileutils'
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
  key = File.basename(file, '.rb')
  class_name = key.split('_').map(&:capitalize).join
  require File.expand_path(file)
  Object.const_get(class_name)
end

def build_catalog(sequences, force: false)
  cache_path = '.cache/catalog.json'
  docs_dir = File.join(__dir__, 'docs', 'sequences')
  FileUtils.mkdir_p(docs_dir)
  FileUtils.mkdir_p('.cache')

  # Load existing to see what we can skip
  existing_catalog = File.exist?(cache_path) ? (JSON.parse(File.read(cache_path)) rescue []) : []
  catalog_map = existing_catalog.each_with_object({}) { |s, h| h[s['key']] = s }
  
  catalog_data = []
  updated = false

  sequences.each do |key, file|
    cached = catalog_map[key]
    # If not forced, and we have a cached score, and the file hasn't changed, reuse it.
    if !force && cached && File.mtime(file) < File.mtime(cache_path)
      catalog_data << cached
    else
      puts "Analyzing: #{key}..."
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
        updated = true
      rescue => e
        puts "Error on #{key}: #{e.message}"
      end
    end
  end

  if updated || !File.exist?(cache_path)
    File.write(cache_path, catalog_data.to_json)
    puts "Catalog metadata synced."
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
  
  LOCK_FILE = ".cache/session.lock"
  File.write(LOCK_FILE, Process.pid)
  
  puts "Launching Discovery Station..."
  pids = []
  pids << spawn("bundle exec ruby lib/visualizers/gui_dashboard.rb", :out=>:out, :err=>:err)
  pids << spawn("bundle exec ruby lib/visualizers/raylib_viewer.rb", :out=>:out, :err=>:err)
  
  begin
    loop do
      pids.each do |pid|
        if Process.waitpid(pid, Process::WNOHANG)
          raise Interrupt
        end
      end
      sleep 0.5
    end
  rescue Interrupt
    puts "\nShutting down..."
  ensure
    File.delete(LOCK_FILE) rescue nil
    pids.each do |pid|
      if RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin/
        system("taskkill /F /PID #{pid} /T >NUL 2>&1")
      else
        Process.kill("KILL", pid) rescue nil
      end
    end
  end
when "build-catalog"
  build_catalog(sequences, force: true)
else
  puts "Usage: bundle exec ruby oeis_cli.rb explore"
end
