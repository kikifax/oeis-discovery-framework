require 'prime'
require_relative '../lib/sequence_template'


class DynamicLogBalancer < OEISSequence
    def initialize
    @name = "Dynamic Log Balancer"
    @description = "a(n) = a(n-1) + n if composite, else a(n-1) - floor(ln(a(n-1))^3). a(0)=1."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + n if composite, else a(n-1) - floor(ln(a(n-1))^3)"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def compute_next
    @n += 1
    
    if @current_a > 1 && @current_a.prime?
      # Stronger reset to handle n-growth
      adjustment = (Math.log(@current_a)**3).floor
      @current_a = (@current_a - adjustment).abs
    else
      @current_a += @n
    end
    
    @current_a
  end
end
