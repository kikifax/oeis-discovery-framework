require 'prime'
require_relative '../lib/sequence_template'

class NaturalStepBouncer < OEISSequence
  def initialize
    super
    @name = "Natural-Step Bouncer"
    @description = "a(n) = a(n-1) + dir * n. Direction flips whenever the previous term |a(n-1)| is prime. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * n; dir = -dir if is_prime(|a(n-1)|)"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @direction = 1
  end

  def compute_next
    @n += 1
    
    # Move based on current direction
    @current_a += (@direction * @n)
    
    # Prepare direction for the NEXT step based on the CURRENT value
    if @current_a.abs > 1 && @current_a.abs.prime?
      @direction *= -1
    end
    
    @current_a
  end
end
