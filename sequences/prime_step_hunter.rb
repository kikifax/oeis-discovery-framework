require 'prime'
require_relative '../lib/sequence_template'

class PrimeStepHunter < OEISSequence
    def initialize
    @name = "Prime-Step Hunter"
    @description = "a(n) = a(n-1) + n if a(n-1) is not prime, else |a(n-1) - p_n|. a(0)=1."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + n if a(n-1) is not prime, else |a(n-1) - p_n|"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @prime_gen = Prime.each
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    if @current_a.prime?
      # Correction: Jump down by the n-th prime
      @current_a = (@current_a - p_n).abs
    else
      # Growth: Add the current index
      @current_a += @n
    end
    
    @current_a
  end
end
