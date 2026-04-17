require_relative '../../lib/sequence_template'

class AbundanceOscillator < OEISSequence
    def initialize
    @name = "Abundance Oscillator"
    @description = "a(n) = a(n-1) + n if a(n-1) is deficient, a(n-1) - n if abundant, a(n-1) + n^2 if perfect. a(0)=1."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + n if a(n-1) is deficient, a(n-1) - n if abundant, a(n-1) + n^2 if perfect"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
  end

  # Sum of proper divisors
  def sigma(n)
    return 0 if n < 1
    sum = 0
    (1..Math.sqrt(n)).each do |i|
      if n % i == 0
        sum += i
        sum += (n / i) if i*i != n
      end
    end
    sum
  end

  def compute_next
    @n += 1
    s = sigma(@current_a)
    
    # Classification based on sum of all divisors vs 2*n
    if s < 2 * @current_a
      # Deficient
      @current_a += @n
    elsif s > 2 * @current_a
      # Abundant
      @current_a = (@current_a - @n).abs
    else
      # Perfect
      @current_a += (@n * @n)
    end
    
    @current_a
  end
end
