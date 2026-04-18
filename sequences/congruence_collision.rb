require 'prime'
require_relative '../lib/sequence_template'

class CongruenceCollision < OEISSequence
  def initialize
    super
    @name = "Congruence Collision Oscillator"
    @description = "Grows by n in current direction. Crashes to a(n) % n and flips direction whenever a(n) % n is prime."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * n; if a(n)%n is prime, a(n) %= n and dir flips"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 1
    @direction = 1
  end

  def compute_next
    @n += 1
    
    @current_a += (@direction * @n)
    
    # Collision check
    remainder = @current_a.abs % @n
    if remainder > 1 && remainder.prime?
      @current_a = (@direction > 0) ? remainder : -remainder
      @direction *= -1
    end
    
    @current_a
  end
end
