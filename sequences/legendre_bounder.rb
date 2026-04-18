require 'prime'
require_relative '../lib/sequence_template'

class LegendreBounder < OEISSequence
    def initialize
    @name = "Legendre Bounder"
    @description = "a(n) = a(n-1) - n if there is a prime in [n^2, n^2 + a(n-1)], else a(n-1) + n. a(0)=1."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) - n if there is a prime in [n^2, n^2 + a(n-1)], else a(n-1) + n"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def has_prime_in_range?(low, high)
    # Use Prime.each to iterate efficiently
    # The first prime p >= low must be <= high
    Prime.each.find { |p| p >= low } <= high
  end

  def compute_next
    @n += 1
    
    # We look for a prime in the window [n^2, n^2 + a(n-1)]
    # Note: if a(n-1) is negative, we'll use its absolute value for the window
    # but the rule says a(n-1) - n or a(n-1) + n.
    
    low = @n * @n
    high = low + @current_a.abs
    
    if has_prime_in_range?(low, high)
      @current_a -= @n
    else
      @current_a += @n
    end
    
    @current_a
  end
end
