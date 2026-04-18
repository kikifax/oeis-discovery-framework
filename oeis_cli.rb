require 'optparse'
require 'prime'
require 'json'
require 'fileutils'
require_relative 'lib/version'

$stdout.sync = true
puts "OEIS Discovery Framework v#{OEIS::VERSION}"

def build_catalog
  puts "[1/3] Syncing metadata..."
  # Minimal catalog builder for launch
  FileUtils.mkdir_p('.cache')
  catalog_data = []
  Dir.glob('sequences/*.rb').each do |file|
    key = File.basename(file, '.rb')
    catalog_data << { key: key, name: key.split('_').map(&:capitalize).join(' '), score: 50 }
  end
  File.write('.cache/catalog.json', catalog_data.to_json)
end

command = ARGV[0]

case command
when "explore"
  build_catalog
  
  # CREATE MOTHER LOCK
  LOCK_FILE = ".cache/session.lock"
  File.write(LOCK_FILE, Process.pid)
  
  puts "[2/3] Launching Station..."
  
  # Use popen to force console sharing on Windows
  pids = []
  
  # Start Dashboard
  pids << spawn("bundle exec ruby lib/visualizers/gui_dashboard.rb", :out=>:out, :err=>:err)
  # Start Viewer
  pids << spawn("bundle exec ruby lib/visualizers/raylib_viewer.rb", :out=>:out, :err=>:err)
  
  puts "\n🚀 Station Active. Close the Dashboard to Exit."
  
  begin
    # Wait for the dashboard pid specifically
    Process.wait(pids[0])
  rescue Interrupt
    puts "\nConsole interrupt..."
  ensure
    File.delete(LOCK_FILE) rescue nil
    pids.each do |pid|
      if RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin/
        system("taskkill /F /PID #{pid} /T >NUL 2>&1")
      else
        Process.kill("KILL", pid) rescue nil
      end
    end
    puts "Cleanup complete."
  end
else
  puts "Usage: bundle exec ruby oeis_cli.rb explore"
end
