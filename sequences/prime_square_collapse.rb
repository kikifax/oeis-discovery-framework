require 'prime'
require_relative '../lib/sequence_template'

class PrimeSquareCollapse < OEISSequence
    def initialize
    @name = "Prime-Square Collapse"
    @description = "a(n) = sqrt(V) if V = a(n-1) + p_n is a perfect square, else V. a(0)=0."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = sqrt(V) if V = a(n-1) + p_n is a perfect square, else V"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @prime_gen = Prime.each
  end

  def is_square?(n)
    return false if n < 0
    root = Math.sqrt(n).to_i
    root * root == n
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    v = @current_a + p_n

    if is_square?(v)
      @current_a = Math.sqrt(v).to_i
    else
      @current_a = v
    end
    
    @current_a
  end
end
