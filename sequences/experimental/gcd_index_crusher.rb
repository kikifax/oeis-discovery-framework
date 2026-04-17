require 'prime'
require_relative '../../lib/sequence_template'

# THE GCD INDEX-CRUSHER RULE:
# 1. We start at 1.
# 2. In each step n, we look at the Greatest Common Divisor (GCD) 
#    of the previous term a(n-1) and the current step index n.
# 3. If they share no factors (GCD is 1):
#    - GROW: Add the n-th prime.
# 4. If they DO share a factor (GCD > 1):
#    - SHRINK: Divide by that shared factor.
#
# WHY THIS IS INTERESTING:
# Unlike the previous rule, the divisor (n) is always small, but it 
# changes every single step. This creates a "friction" that tries to 
# keep the sequence from growing too fast. It is mathematically 
# unclear if the sequence eventually escapes to infinity or stays 
# trapped in a "low-altitude" orbit.

class GcdIndexCrusher < OEISSequence
    def initialize
    @name = "GCD Index-Crusher"
    @description = "Add p_n if gcd(a(n-1), n)==1, else divide by gcd(a(n-1), n)."
    @author = "Andi"
    @rank = "Experimental"
    @formula = "Add p_n if gcd(a(n-1), n)==1, else divide by gcd(a(n-1), n)"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 1
    @prime_gen = Prime.each
    @prime_gen.next # skip p_1=2 to align with n=2
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    g = @current_a.gcd(@n)
    
    if g == 1
      @current_a += p_n
    else
      @current_a /= g
    end
    
    @current_a
  end
end
