require 'prime'
require_relative '../../lib/sequence_template'

# THE GCD PRIME-STEP RULE:
# 1. We start at 1.
# 2. In each step n, we look at the previous number a(n-1).
# 3. We check the GCD (Greatest Common Divisor) of a(n-1) and the n-th prime p_n.
# 4. Since p_n is prime, there are only two possibilities:
#    - GCD is 1: They share no factors. (p_n does not divide a(n-1))
#    - GCD is p_n: They share a factor. (p_n divides a(n-1))
# 5. If GCD is 1, we GROW:
#    - Add the prime: a(n) = a(n-1) + p_n.
# 6. If GCD is p_n, we SHRINK:
#    - Divide by the prime: a(n) = a(n-1) / p_n.
#
# WHY THIS IS INTERESTING:
# It asks a deep question about prime sums: How often is the sum of some 
# primes divisible by the "next" prime? If it happens often, the sequence 
# stays small. If it stops happening, the sequence flies to infinity.

class GcdPrimeStep < OEISSequence
    def initialize
    @name = "GCD Prime-Step"
    @description = "Add p_n if it doesn't divide a(n-1), otherwise divide by p_n."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "Add p_n if it doesn't divide a(n-1), otherwise divide by p_n"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @prime_gen = Prime.each
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    if @current_a % p_n == 0
      # Shrink
      @current_a /= p_n
    else
      # Grow
      @current_a += p_n
    end
    
    @current_a
  end
end
