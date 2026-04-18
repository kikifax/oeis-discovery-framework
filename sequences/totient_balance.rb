require 'prime'
require_relative '../lib/sequence_template'

# THE TOTIENT BALANCE RULE:
# 1. We start at 3.
# 2. In each step n, we look at the previous number a(n-1).
# 3. We check if a(n-1) is "Prime-like" or "Composite-heavy".
#    - Prime-like: More than half the numbers below it are coprime to it (phi(n) > n/2).
#    - Composite-heavy: Half or more of the numbers below it share a factor with it (phi(n) <= n/2).
# 4. If it is Prime-like, we move UP by the n-th prime.
# 5. If it is Composite-heavy, we move DOWN by the n-th prime (and take the absolute value to stay positive).
#
# WHY THIS WORKS:
# Primes and "thin" numbers always push the sequence higher.
# Highly divisible numbers (like 6, 12, 30) act as gravity wells that pull the sequence back toward zero.

class TotientBalance < OEISSequence
    def initialize
    @name = "Totient Balance"
    @description = "Step up if previous term is 'prime-heavy' (phi(n) > n/2), otherwise step down by the n-th prime."
    @author = "Andi"
    @rank = "Medium Potential"
    @formula = "Step up if previous term is 'prime-heavy' (phi(n) > n/2), otherwise step down by the n-th prime"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 3
    @n = 0
    @prime_gen = Prime.each
  end

  def phi(n)
    return 0 if n == 0
    return 1 if n == 1
    result = n
    Prime.prime_division(n).each { |p, _| result -= result / p }
    result
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    if phi(@current_a) > @current_a / 2.0
      @current_a += p_n
    else
      @current_a = (@current_a - p_n).abs
    end
    
    @current_a
  end
end
