require 'prime'
require_relative '../lib/sequence_template'

class LegendreModReset < OEISSequence
    def initialize
    @name = "Legendre Mod-Reset"
    @description = "a(n) = a(n-1) + n if not prime, else a(n-1) % (next_prime(n^2) - n^2 + 1). a(0)=1."
    @author = "Andi"
    @rank = "Medium Potential"
    @formula = "a(n) = a(n-1) + n if not prime, else a(n-1) % (next_prime(n^2) - n^2 + 1)"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def next_prime(k)
    # Efficiently find next prime > k
    Prime.each.find { |p| p > k }
  end

  def compute_next
    @n += 1
    
    if @current_a.prime?
      n_sq = @n * @n
      gap = next_prime(n_sq) - n_sq
      @current_a = @current_a % (gap + 1)
    else
      @current_a += @n
    end
    
    @current_a
  end
end
