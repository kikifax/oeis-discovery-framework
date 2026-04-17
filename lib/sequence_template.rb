require 'json'
require 'fileutils'

# Base class for OEIS-style sequences
class OEISSequence
  attr_reader :name, :description, :author, :rank, :formula, :oeis_id, :terms

  def initialize
    @name = "Unnamed Sequence"
    @description = "No description provided."
    @author = "Anonymous"
    @rank = "Experimental"
    @formula = "Not defined"
    @oeis_id = "Pending"
    @terms = []
  end

  # This is the core logic that subclasses will override
  def compute_next
    raise NotImplementedError, "Subclasses must implement compute_next"
  end

  def generate(count)
    @terms ||= []
    
    # Try to load from disk if memory is empty
    load_cache if @terms.empty?
    
    # If we still don't have enough, generate more
    if @terms.size < count
      needed = count - @terms.size
      needed.times { @terms << compute_next }
      save_cache
    end
    
    @terms[0...count]
  end

  # Paths for cache files
  def cache_dir
    dir = File.join(Dir.pwd, '.cache', self.class.to_s.downcase)
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    dir
  end

  def terms_path
    File.join(cache_dir, 'terms.bin')
  end

  def state_path
    File.join(cache_dir, 'state.json')
  end

  # Efficiency: Use binary packing for terms
  def save_cache
    @terms ||= []
    # Save terms as 64-bit signed integers
    File.open(terms_path, 'wb') { |f| f.write(@terms.pack('q*')) }
    
    # Save instance variables (state) to resume later
    state = {}
    instance_variables.each do |var|
      next if [:@terms, :@pi_cache, :@prime_gen, :@cache, :@cache_gen].include?(var)
      state[var] = instance_variable_get(var)
    end
    File.write(state_path, state.to_json)
  end

  def load_cache
    @terms = []
    if File.exist?(terms_path)
      begin
        binary_data = File.binread(terms_path)
        @terms = binary_data.unpack('q*') || []
        
        if File.exist?(state_path)
          state = JSON.parse(File.read(state_path))
          state.each do |var, val|
            instance_variable_set(var, val)
          end
          # Re-initialize the prime generator if it was being used
          if instance_variable_defined?(:@prime_gen)
            @prime_gen = Prime.each
            @n.to_i.times { @prime_gen.next } if @n.to_i > 0
          end
        end
      rescue => e
        puts "Warning: Cache corrupted, resetting state. (#{e.message})"
        reset_state
      end
    else
      reset_state
    end
  end

  # Reset any internal state (counters, current values)
  def reset_state
    raise NotImplementedError, "Subclasses must implement reset_state"
  end

  def to_oeis_format
    @terms.join(", ")
  end

  def analyze(count)
    terms = generate(count)
    return if terms.empty?

    max_val = terms.max
    min_val = terms.min
    avg = terms.sum.to_f / terms.size
    
    # 1. Growth Analysis
    # Compare first 10% vs last 10%
    chunk = (count * 0.1).to_i
    start_avg = terms[0...chunk].sum.to_f / chunk
    end_avg = terms[-chunk..-1].sum.to_f / chunk
    growth_factor = end_avg / [start_avg, 1].max
    
    growth_type = case
      when growth_factor > 10 then "Explosive (Exponential/High Poly)"
      when growth_factor > 1.5 then "Steady Growth"
      when growth_factor < 0.5 then "Decreasing/Converging"
      else "Stagnant/Oscillating"
    end

    # 2. Periodicity Check
    # Look for repeating sub-sequences of length 2..20
    is_periodic = false
    (2..20).each do |len|
      next if terms.size < len * 3
      if terms[-len..-1] == terms[-(len*2)...-len] && terms[-len..-1] == terms[-(len*3)...-(len*2)]
        is_periodic = true
        break
      end
    end

    # 3. Step Dynamics (Swings)
    diffs = terms.each_cons(2).map { |a, b| (a - b).abs }
    max_swing = diffs.max || 0
    avg_swing = diffs.empty? ? 0 : diffs.sum.to_f / diffs.size
    variance = diffs.empty? ? 0 : diffs.map { |d| (d - avg_swing)**2 }.sum / diffs.size
    erraticness = Math.sqrt(variance)
    
    # 4. Resets (Sudden drops > 50% of current value)
    resets = terms.each_cons(2).count { |a, b| b < a * 0.5 }
    
    # 5. Composition Metrics
    unique_ratio = terms.uniq.size.to_f / terms.size
    zero_count = terms.count(0)
    prime_count = terms.count { |t| t > 1 && t.prime? }

    # OEIS Fitness Scoring Breakdown (Heuristic Model)
    # This scoring system rewards sequences that show 'organized chaos'—mathematically
    # rigorous rules that produce unpredictable but non-random results.
    scores = {}
    
    # 1. Diversity (0-25): How many unique numbers?
    # OEIS editors often reject sequences that simply cycle through a small set of values.
    # Higher diversity implies a more complex/richer mathematical state space.
    scores[:diversity] = [unique_ratio * 25, 25].min
    
    # 2. Activity/Entropy (0-25): High reset density or erratic swings.
    # A sequence that just grows linearly is 'boring'. We reward sequences with 
    # 'feedback loops' where hitting a certain number (like a prime) triggers a crash.
    reset_score = (resets.to_f / count) * 200
    swing_score = (erraticness / [avg, 1].max) * 50
    scores[:activity] = [[reset_score + swing_score, 25].min, 0].max
    
    # 3. Mathematical Novelty (0-25): Interaction with primes and zeros.
    # OEIS is fundamentally about number theory. Sequences that frequently land on
    # primes or return to zero (roots/resets) have higher 'inter-connectivity' 
    # with existing A-numbers in the database.
    novelty_ratio = (prime_count + zero_count).to_f / count
    scores[:novelty] = [novelty_ratio * 50, 25].min
    
    # 4. Longevity/Stability (0-25): Anti-triviality and computability.
    # Points are deducted for trivial periodicity (cycle of 1, 2, 1, 2) or for
    # exploding so fast that b-files (10,000 terms) become impossible to compute/store.
    stability = 25
    stability -= 20 if is_periodic
    stability -= 10 if growth_factor > 1000 
    scores[:longevity] = [stability, 0].max

    total_score = scores.values.sum

    {
      metadata: { name: @name, rank: @rank, formula: @formula },
      stats: {
        terms: terms.size,
        max: max_val,
        min: min_val,
        avg: avg.round(2),
        growth_type: growth_type,
        is_periodic: is_periodic
      },
      dynamics: {
        max_swing: max_swing,
        avg_swing: avg_swing.round(2),
        erraticness: erraticness.round(2),
        resets: resets
      },
      composition: {
        prime_density: (prime_count.to_f / terms.size).round(4),
        zero_density: (zero_count.to_f / terms.size).round(4),
        unique_ratio: unique_ratio.round(4)
      },
      scoring: scores,
      fitness_score: total_score.round(1)
    }
  end
end
