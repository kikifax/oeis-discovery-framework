require 'prime'
require_relative '../lib/sequence_template'


class ChaoticPrimeSpring < OEISSequence
    def initialize
    @name = "Chaotic Prime Spring"
    @description = "a(n) = a(n-1) + (n ^ waiting_time). If prime, a(n) = a(n) % (floor(sqrt(a(n))) + 1)."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + (n ^ waiting_time)"
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
    # XOR growth breaks the triangular number trap
    @current_a += (@n ^ @waiting_time)
    @waiting_time += 1
    
    if @current_a > 1 && @current_a.prime?
      # Massive reset: Modulo by sqrt(a)
      @current_a = @current_a % (Math.sqrt(@current_a).floor + 1)
      @waiting_time = 0 
    end
    
    @current_a
  end
end
