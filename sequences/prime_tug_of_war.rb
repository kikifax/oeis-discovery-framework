require 'prime'
require_relative '../lib/sequence_template'

class PrimeTugOfWar < OEISSequence
    def initialize
    @name = "Prime Tug-of-War"
    @description = "a(n) = a(n-1) + p_n if that sum is prime, else abs(a(n-1) - LPF(a(n-1) + p_n))."
    @author = "Andi"
    @rank = "Medium Potential"
    @formula = "a(n) = a(n-1) + p_n if that sum is prime, else abs(a(n-1) - LPF(a(n-1) + p_n))"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @prime_gen = Prime.each
  end

  def lpf(n)
    return 0 if n == 0
    Prime.prime_division(n.abs).map(&:first).max || 0
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    v = @current_a + p_n

    if v.prime?
      @current_a = v
    else
      @current_a = (@current_a - lpf(v)).abs
    end
    
    @current_a
  end
end
