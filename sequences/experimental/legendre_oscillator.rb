require 'prime'
require_relative '../../lib/sequence_template'

class LegendreOscillator < OEISSequence
    def initialize
    @name = "Legendre Oscillator"
    @description = "a(n) = a(n-1) + n if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|. a(0)=1."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + n if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def next_prime(k)
    # Prime.find is not standard, we use Prime.each
    Prime.each(k + 500).find { |p| p > k }
  end

  def compute_next
    @n += 1
    
    if @current_a.prime?
      # The Legendre Reset: use the gap between n^2 and next prime
      n_sq = @n * @n
      gap = next_prime(n_sq) - n_sq
      @current_a = (@current_a - @n * gap).abs
    else
      # Normal growth
      @current_a += @n
    end
    
    @current_a
  end
end
