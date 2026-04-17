require 'prime'
require_relative '../../lib/sequence_template'


class PrimeSpring < OEISSequence
    def initialize
    @name = "Prime Spring"
    @description = "a(n) = a(n-1) + n. If prime, a(n) = a(n) % (steps_since_last_prime * floor(ln(a(n))) + 1)."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + n"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @steps_since_last = 0
  end

  def compute_next
    @n += 1
    @current_a += @n
    @steps_since_last += 1
    
    if @current_a > 1 && @current_a.prime?
      # The spring constant depends on the wait time and the prime density
      k = @steps_since_last * Math.log(@current_a).floor
      @current_a = @current_a % (k + 1)
      @steps_since_last = 0 # Reset the spring
    end
    
    @current_a
  end
end
