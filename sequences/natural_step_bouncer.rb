require 'prime'
require_relative '../lib/sequence_template'

class NaturalStepBouncer < OEISSequence
  def initialize
    super
    @name = "Natural-Step Bouncer"
    @description = "a(n) = a(n-1) + dir * n. Result mirrored at 0. Direction flips if |a(n)| + p_n is prime. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = |a(n-1) + dir * n|; dir = -dir if is_prime(|a(n)| + p_n)"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @direction = 1
  end

  def compute_next
    @n += 1
    
    # 1. Standard move
    next_v = @current_a + (@direction * @n)
    
    # 2. Mirror (Stay positive)
    @current_a = next_v.abs
    if next_v <= 0
      @direction = 1
    end
    
    # 3. Breaking the Triangular Trap
    # Use the n-th prime as an offset so we don't land in the n(n+1)/2 sieve
    p_n = self.class.get_prime(@n)
    if (@current_a + p_n).prime?
      @direction *= -1
    end
    
    @current_a
  end
  
  def generate(count)
    puts "[Station] Recalculating: Breaking the Triangular Trap..."
    super(count)
  end
end
