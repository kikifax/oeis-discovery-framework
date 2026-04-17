require 'prime'
require_relative '../../lib/sequence_template'

class LiouvilleOscillator < OEISSequence
    def initialize
    @name = "Liouville Prime Oscillator"
    @description = "a(n) = a(n-1) + p_n if Omega(a(n-1)) is even, else |a(n-1) - p_n|. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + p_n if Omega(a(n-1)) is even, else |a(n-1) - p_n|"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @prime_gen = Prime.each
  end

  def omega(n)
    return 0 if n <= 1
    factors = Prime.prime_division(n.abs)
    factors.map(&:last).sum
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    # Omega(n) is the number of prime factors with multiplicity
    if omega(@current_a).even?
      @current_a += p_n
    else
      @current_a = (@current_a - p_n).abs
    end
    
    @current_a
  end
end
