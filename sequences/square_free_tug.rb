require 'prime'
require_relative '../lib/sequence_template'

# THE SQUARE-FREE TUG RULE:
# 1. We start at 1.
# 2. In each step n, we look at the previous number a(n-1).
# 3. We check if a(n-1) is "Square-Free":
#    - Square-Free: No prime factor is repeated (e.g. 6 = 2 * 3).
#    - Not Square-Free: Contains at least one square (e.g. 12 = 2^2 * 3).
# 4. If it is Square-Free, we GROW:
#    - Add the n-th prime.
# 5. If it is NOT Square-Free, we SHRINK:
#    - Divide it by its largest square factor (e.g. 12 / 4 = 3).
#
# WHY THIS IS INTERESTING:
# It's a "climb and crash" system. The sequence grows smoothly until it 
# accidentally lands on a "heavy" number that contains a square. 
# Then it instantly collapses back down to its square-free core.

class SquareFreeTug < OEISSequence
    def initialize
    @name = "Square-Free Tug"
    @description = "Add n-th prime if square-free, else divide by largest square factor."
    @author = "Andi"
    @rank = "Medium Potential"
    @formula = "Add n-th prime if square-free, else divide by largest square factor"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 0
    @prime_gen = Prime.each
  end

  def largest_square_factor(n)
    return 1 if n < 1
    factors = Prime.prime_division(n)
    lsf = 1
    factors.each do |p, e|
      # For each p^e, the square part is p^(2 * floor(e/2))
      square_part = p ** (2 * (e / 2))
      lsf *= square_part
    end
    lsf
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    lsf = largest_square_factor(@current_a)
    
    if lsf == 1
      # Number is square-free (or 1)
      @current_a += p_n
    else
      # Number contains a square: COLLAPSE
      @current_a /= lsf
    end
    
    @current_a
  end
end
