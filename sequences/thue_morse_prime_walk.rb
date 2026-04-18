require 'prime'
require_relative '../lib/sequence_template'

class ThueMorsePrimeWalk < OEISSequence
  def initialize
    super
    @name = "Thue-Morse Prime Walk"
    @description = "a(n) = a(n-1) + p_n if popcount(a(n-1)) is even, else a(n-1) - p_n. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + (-1)^popcount(a(n-1)) * p_n"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @prime_gen = Prime.each
  end

  def popcount(n)
    n.abs.to_s(2).count('1')
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    # Even popcount = move UP
    # Odd popcount = move DOWN
    if popcount(@current_a).even?
      @current_a += p_n
    else
      @current_a -= p_n
    end
    
    @current_a
  end
end
