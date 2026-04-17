require 'optparse'
require 'prime'
require_relative 'lib/sequence_template'

# Dynamically load all sequences from the sequences/ directory
def load_sequences
  sequences = {}
  # Use a temporary set to keep track of already loaded classes to avoid duplicates
  existing_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }.to_a

  Dir.glob(File.join(__dir__, 'sequences', '**', '*.rb')).each do |file|
    require_relative file
    
    # After requiring, find the NEW class added to the system
    new_classes = ObjectSpace.each_object(Class).select { |c| c < OEISSequence }
    klass = (new_classes - existing_classes).first
    
    if klass
      key = File.basename(file, '.rb')
      sequences[key] = klass
      existing_classes << klass
    end
  end
  sequences
end

def list_sequences(sequences)
  puts "%-30s | %-15s | %s" % ["Key", "Rank", "Name"]
  puts "-" * 80
  
  # Group by rank
  grouped = sequences.values.group_by { |k| k.new.rank }
  
  ["High Potential", "Medium Potential", "Experimental"].each do |rank|
    next unless grouped[rank]
    grouped[rank].each do |klass|
      instance = klass.new
      key = sequences.key(klass)
      puts "%-30s | %-15s | %s" % [key, rank, instance.name]
    end
  end
end

def build_catalog(sequences)
  File.open("CATALOG.md", "w") do |f|
    f.puts "# OEIS Discovery Catalog"
    f.puts "\nThis catalog is auto-generated and lists all sequences currently in the discovery framework."
    
    ["High Potential", "Medium Potential", "Experimental"].each do |rank|
      f.puts "\n## #{rank} Sequences"
      f.puts "\n| Key | Name | Formula | Description |"
      f.puts "| :--- | :--- | :--- | :--- |"
      
      sequences.each do |key, klass|
        instance = klass.new
        next unless instance.rank == rank
        f.puts "| `#{key}` | #{instance.name} | `#{instance.formula}` | #{instance.description} |"
      end
    end
  end
  puts "CATALOG.md has been generated."
end

sequences = load_sequences

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby oeis_cli.rb [options] [command] [sequence_key] [count]"
  
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    puts "\nCommands:"
    puts "  list              List all available sequences"
    puts "  generate <key> <n>  Print the first n terms of a sequence"
    puts "  analyze <key> <n>   Perform statistical analysis and fitness scoring"
    puts "  plot <key> <n>      Launch terminal plotter for first n terms"
    puts "  gui <key> <n>       Launch graphical explorer for first n terms"
    puts "  bfile <key> <n>     Generate a b-file in b_files/ directory"
    puts "  build-catalog     Auto-generate CATALOG.md"
    exit
  end
end.parse!

command = ARGV[0]
key = ARGV[1]
count = (ARGV[2] || 100).to_i

case command
when "list"
  list_sequences(sequences)
when "build-catalog"
  build_catalog(sequences)
when "generate", "plot", "gui", "bfile", "analyze"
  unless sequences[key]
    puts "Error: Sequence '#{key}' not found. Use 'ruby oeis_cli.rb list' to see available keys."
    exit 1
  end
  
  instance = sequences[key].new
  
  case command
  when "analyze"
    puts "=========================================================="
    puts "      FULL OEIS FITNESS REPORT: #{instance.name}"
    puts "=========================================================="
    report = instance.analyze(count)
    
    puts "\n[ 1. BASIC STATISTICS ]"
    puts "Terms Generated:  #{report[:stats][:terms]}"
    puts "Value Range:      #{report[:stats][:min]} to #{report[:stats][:max]}"
    puts "Average Value:    #{report[:stats][:avg]}"
    puts "Growth Pattern:   #{report[:stats][:growth_type]}"
    puts "Is Periodic?      #{report[:stats][:is_periodic] ? 'YES (Warning: Low Fitness)' : 'No'}"
    
    puts "\n[ 2. DYNAMIC BEHAVIOR ]"
    puts "Average Swing:    #{report[:dynamics][:avg_swing]}"
    puts "Max Step Swing:   #{report[:dynamics][:max_swing]}"
    puts "Erraticness:      #{report[:dynamics][:erraticness]} (SD of swings)"
    puts "Significant Drops:#{report[:dynamics][:resets]} (>50% reset)"
    
    puts "\n[ 3. COMPOSITION ]"
    puts "Prime Density:    #{(report[:composition][:prime_density] * 100).round(2)}%"
    puts "Zero Density:     #{(report[:composition][:zero_density] * 100).round(2)}%"
    puts "Uniqueness Ratio: #{(report[:composition][:unique_ratio] * 100).round(2)}%"
    
    puts "\n[ 4. SCORING BREAKDOWN ]"
    puts "Diversity Score:  #{report[:scoring][:diversity].round(1)} / 25"
    puts "Activity Score:   #{report[:scoring][:activity].round(1)} / 25"
    puts "Novelty Score:    #{report[:scoring][:novelty].round(1)} / 25"
    puts "Longevity Score:  #{report[:scoring][:longevity].round(1)} / 25"
    
    puts "\n----------------------------------------------------------"
    printf("FINAL FITNESS SCORE: %.1f / 100\n", report[:fitness_score])
    puts "----------------------------------------------------------"
    
    case report[:fitness_score]
    when 0..30 then puts "STATUS: POOR - High probability of being trivial or periodic."
    when 31..60 then puts "STATUS: FAIR - Interesting behavior, but may lack enough 'surprise'."
    when 61..85 then puts "STATUS: STRONG - Highly recommended for OEIS search/submission."
    else puts "STATUS: ELITE - Exceptional mathematical profile. Submit ASAP."
    end
    puts "=========================================================="
  when "generate"
    puts "Generating #{count} terms for #{instance.name}..."
    puts instance.generate(count).join(", ")
  when "plot"
    require_relative 'lib/visualizers/oeis_plotter'
    terms = instance.generate(count)
    OEISPlotter.plot(terms)
  when "gui"
    # Note: Glimmer needs to be in the same process, we'll shell out to be safe
    # or require it if the environment is set up.
    system "ruby lib/visualizers/oeis_gui.rb sequences/*/#{key}.rb #{count}"
  when "bfile"
    puts "Generating b-file for #{instance.name} (up to a(#{count-1}))..."
    terms = instance.generate(count)
    path = File.join(__dir__, 'b_files', "b_#{key}.txt")
    File.open(path, "w") do |f|
      terms.each_with_index { |v, i| f.puts "#{i} #{v}" }
    end
    puts "Saved to #{path}"
  end
else
  puts "Unknown command. Use --help for usage."
end
