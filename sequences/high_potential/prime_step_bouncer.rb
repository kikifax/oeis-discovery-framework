require 'prime'
require_relative '../../lib/sequence_template'

class PrimeStepBouncer < OEISSequence
  def initialize
    super
    @name = "Prime-Step Bouncer"
    @description = "a(n) = a(n-1) + dir * p_n. Direction flips whenever the previous term |a(n-1)| is prime. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * p_n; dir = -dir if is_prime(|a(n-1)|)"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @direction = 1
    @prime_gen = Prime.each
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    # Move based on current direction
    @current_a += (@direction * p_n)
    
    # Prepare direction for the NEXT step based on the CURRENT value
    if @current_a.abs > 1 && @current_a.abs.prime?
      @direction *= -1
    end
    
    @current_a
  end
end
