require 'prime'
require_relative '../../lib/sequence_template'

class PrimeStepDivisibilityWalk < OEISSequence
  def initialize
    super
    @name = "Prime-Step Divisibility Walk"
    @description = "a(n) = a(n-1) + dir * p_n. The direction flips whenever a(n) is a multiple of n. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * p_n; dir = -dir if a(n) % n == 0"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @direction = 1
    @prime_gen = Prime.each
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    @current_a += (@direction * p_n)
    
    # The condition that thins out (1/n probability)
    if (@current_a % @n) == 0
      @direction *= -1
    end
    
    @current_a
  end
end
