require 'prime'
require_relative '../lib/sequence_template'

class NaturalStepBouncer < OEISSequence
  def initialize
    super
    @name = "Natural-Step Bouncer (Pure)"
    @description = "a(n) = a(n-1) + dir * n. Direction flips if a(n) is prime. Mirrors at 0. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = |a(n-1) + dir * n|; dir flips if is_prime(a(n))"
    reset_state
  end

  def reset_state
    @current_a = 1 # Starting at 1 breaks the n(n+1)/2 composite trap
    @n = 0
    @direction = 1
  end

  def compute_next
    @n += 1
    
    # 1. Standard Pure Move
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
  
  def generate(count)
    puts "[Station] Calculating PURE Natural Step Bouncer..."
    super(count)
  end
end
