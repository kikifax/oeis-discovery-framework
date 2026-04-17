require 'prime'
require_relative '../../lib/sequence_template'

class SlowGrownLegendre < OEISSequence
    def initialize
    @name = "Slow-Grown Legendre"
    @description = "a(n) = a(n-1) + SPF(n) if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + SPF(n) if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  def spf(n)
    return 1 if n <= 1
    Prime.prime_division(n).map(&:first).min
  end

  def next_prime(k)
    Prime.each.find { |p| p > k }
  end

  def compute_next
    @n += 1
    
    if @current_a.prime?
      n_sq = @n * @n
      gap = next_prime(n_sq) - n_sq
      @current_a = (@current_a - @n * gap).abs
    else
      @current_a += spf(@n)
    end
    
    @current_a
  end
end
