require 'prime'
require_relative '../lib/sequence_template'

class NaturalStepBouncer < OEISSequence
  def initialize
    super
    @name = "Natural-Step Bouncer"
    @description = "a(n) = a(n-1) + dir * n. Mirror at 0. Direction flips if |a(n)|+p_n is prime AND momentum >= sqrt(n). a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = |a(n-1) + dir * n|; flips if (is_prime(|a|+p_n) && streak > sqrt(n))"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @direction = 1
    @streak = 0
  end

  def compute_next
    @n += 1
    @streak += 1
    
    # 1. Standard move
    next_v = @current_a + (@direction * @n)
    
    # 2. Mirror at zero
    @current_a = next_v.abs
    if next_v <= 0
      @direction = 1
      @streak = 0
    end
    
    # 3. Momentum Flip
    # We only allow a flip if we've been in this direction long enough to 'build speed'
    p_n = self.class.get_prime(@n)
    if (@current_a + p_n).prime?
      if @streak >= Math.sqrt(@n).floor
        @direction *= -1
        @streak = 0
      end
    end
    
    @current_a
  end
  
  def generate(count)
    puts "[Station] Recalculating NSB with Momentum Logic..."
    super(count)
  end
end
