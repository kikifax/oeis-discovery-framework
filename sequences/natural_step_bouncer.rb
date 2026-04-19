require 'prime'
require_relative '../lib/sequence_template'

class NaturalStepBouncer < OEISSequence
  def initialize
    super
    @name = "Natural-Step Bouncer"
    @description = "a(n) = a(n-1) + dir * n. Result mirrored at 0. Direction flips if a(n) is prime. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = |a(n-1) + dir * n|; dir flips if is_prime(a(n))"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @direction = 1
  end

  # CRITICAL: This was the source of the 'Clock Signal' bug.
  # We must replay the direction logic perfectly to know our current heading.
  def reconstruct_state(terms)
    reset_state
    return if terms.empty?
    
    # We must REPLAY to find the correct @direction
    current_replay_a = 1
    current_replay_dir = 1
    
    terms.each_with_index do |val, i|
      step_n = i + 1
      # Replicate 'compute_next' logic exactly
      next_v = current_replay_a + (current_replay_dir * step_n)
      
      # Mirror
      current_replay_a = next_v.abs
      if next_v <= 0
        current_replay_dir = 1
      end
      
      # Flip
      if current_replay_a > 1 && current_replay_a.prime?
        current_replay_dir *= -1
      end
    end
    
    @current_a = current_replay_a
    @direction = current_replay_dir
    @n = terms.size
  end

  def compute_next
    @n += 1
    
    # 1. Potential Move
    next_v = @current_a + (@direction * @n)
    
    # 2. Mirror (Stay positive)
    @current_a = next_v.abs
    if next_v <= 0
      @direction = 1
    end
    
    # 3. Pure Prime Flip
    if @current_a > 1 && @current_a.prime?
      @direction *= -1
    end
    
    @current_a
  end
end
