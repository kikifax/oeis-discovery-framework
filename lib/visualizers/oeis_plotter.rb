# A terminal-based plotter for OEIS sequences
class OEISPlotter
  def self.plot(terms, width = 80, height = 20)
    return if terms.empty?
    
    max_val = terms.max
    min_val = terms.min
    range = [max_val - min_val, 1].max
    
    # Create an empty grid
    grid = Array.new(height) { Array.new(width, " ") }
    
    terms.each_with_index do |val, i|
      next if i >= width
      
      # Map value to y-coordinate
      y = ((val - min_val).to_f / range * (height - 1)).round
      grid[(height - 1) - y][i] = "•"
    end
    
    # Print the graph
    puts "-" * (width + 10)
    grid.each_with_index do |row, i|
      label = i == 0 ? max_val.to_s : (i == height - 1 ? min_val.to_s : "")
      printf("%10s | %s\n", label, row.join)
    end
    puts "-" * (width + 10)
  end

  def self.interactive(sequence_instance)
    puts "Generating 1000 terms for exploration..."
    all_terms = sequence_instance.generate(1000)
    
    start_idx = 0
    end_idx = 100
    
    loop do
      puts "\nPlotting #{sequence_instance.name} [#{start_idx} to #{end_idx}]"
      plot(all_terms[start_idx...end_idx])
      
      print "\nEnter zoom range (e.g. '0 500') or 'q' to quit: "
      input = gets.chomp
      break if input.downcase == 'q'
      
      parts = input.split.map(&:to_i)
      if parts.size == 2
        start_idx = [0, parts[0]].max
        end_idx = [start_idx + 10, parts[1], 1000].min
      end
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby oeis_plotter.rb <sequence_file_path>"
    exit
  end

  require_relative ARGV[0].sub(".rb", "")
  
  # Find the class that inherits from OEISSequence
  seq_class = ObjectSpace.each_object(Class).find { |c| c < OEISSequence }
  
  if seq_class
    OEISPlotter.interactive(seq_class.new)
  else
    puts "Error: No OEISSequence subclass found in #{ARGV[0]}"
  end
end
