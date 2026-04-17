require 'prime'
require_relative '../../lib/sequence_template'

class DivisorResidencyOscillator < OEISSequence
  def initialize
    super
    @name = "Divisor-Residency Oscillator"
    @description = "a(n) = a(n-1) + n. If (number of divisors of a(n)) % n is prime, a(n) = |a(n) - n^2|. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + n; if sigma0(a(n)) % n is prime, a(n) = abs(a(n) - n^2)"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def sigma0(n)
    return 1 if n <= 1
    factors = Prime.prime_division(n.abs)
    # sigma0 is the product of (exponent + 1)
    factors.reduce(1) { |prod, (_, e)| prod * (e + 1) }
  end

  def compute_next
    @n += 1
    @current_a += @n
    
    # The condition that thins out over time
    d_count = sigma0(@current_a)
    
    if (d_count % @n) > 1 && (d_count % @n).prime?
      # Sudden crash based on n^2 to pull it back from a(n) ~ n^2/2
      @current_a = (@current_a - (@n * @n)).abs
    end
    
    @current_a
  end
end
