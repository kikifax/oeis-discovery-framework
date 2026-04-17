require 'prime'
require_relative '../../lib/sequence_template'

class PrimeHunterFibonacci < OEISSequence
  def initialize
    super
    @name = "Accelerated Prime Fibonacci"
    @description = "a(n) = a(n-1) + a(n-2) + momentum if a(n-1) is prime, else |a(n-1) - a(n-2)|. Momentum increments during growth and resets on crashes."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + a(n-2) + m if is_prime(a(n-1)) else |a(n-1)-a(n-2)|"
    reset_state
  end

  def reset_state
    @a = 2
    @b = 3
    @momentum = 1
    @n = 1
    @terms = [2, 3]
  end

  def compute_next
    @n += 1
    
    if @b.abs > 1 && @b.abs.prime?
      next_val = @a + @b + @momentum
      @momentum += 1
    else
      next_val = (@a - @b).abs
      @momentum = 1
    end
    
    @a = @b
    @b = next_val
    @b
  end

  def generate(count)
    # Clear cache for logic changes
    @terms = [2, 3]
    @a = 2
    @b = 3
    @momentum = 1
    
    (count - 2).times { @terms << compute_next }
    @terms[0...count]
  end
end
