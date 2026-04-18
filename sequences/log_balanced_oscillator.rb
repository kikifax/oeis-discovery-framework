require 'prime'
require_relative '../lib/sequence_template'


class LogBalancedOscillator < OEISSequence
    def initialize
    @name = "Log-Balanced Oscillator"
    @description = "a(n) = a(n-1) + 1 if composite, else a(n-1) - floor(ln(a(n-1))^2). a(0)=1."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + 1 if composite, else a(n-1) - floor(ln(a(n-1))^2)"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def compute_next
    @n += 1
    
    if @current_a > 2 && @current_a.prime?
      # The Log-Reset: Pull back based on the square of the log
      # This compensates for the increasing rarity of primes.
      adjustment = (Math.log(@current_a)**2).floor
      @current_a = (@current_a - adjustment).abs
    else
      @current_a += 1
    end
    
    @current_a
  end
end
