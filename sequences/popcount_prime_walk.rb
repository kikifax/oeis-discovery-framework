require 'prime'
require_relative '../lib/sequence_template'


class PopcountPrimeWalk < OEISSequence
    def initialize
    @name = "Popcount-Prime Walk"
    @description = "a(n) = a(n-1) + popcount(n). If prime, a(n) = abs(a(n-1) - n). a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + popcount(n)"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
  end

  def popcount(n)
    n.to_s(2).count('1')
  end

  def compute_next
    @n += 1
    
    if @current_a > 1 && @current_a.prime?
      # Pull back by the current index
      @current_a = (@current_a - @n).abs
    else
      # Grow by binary density
      @current_a += popcount(@n)
    end
    
    @current_a
  end
end
