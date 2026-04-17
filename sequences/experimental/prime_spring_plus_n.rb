require 'prime'
require_relative '../../lib/sequence_template'


class PrimeSpringPlusN < OEISSequence
    def initialize
    @name = "Prime Spring (+n)"
    @description = "a(n) = a(n-1) + n. If a(n) is prime, a(n) = a(n) % (waiting_time * floor(ln(a(n))) + 1)."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + n"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @waiting_time = 0
  end

  def compute_next
    @n += 1
    @current_a += @n
    @waiting_time += 1
    
    if @current_a > 1 && @current_a.prime?
      # The spring constant: wait time * log(a)
      # We add 1 to avoid modulo 0
      k = (@waiting_time * Math.log(@current_a)).floor + 1
      @current_a = @current_a % k
      @waiting_time = 0 # Reset the spring tension
    end
    
    @current_a
  end
end
