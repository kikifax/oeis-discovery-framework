require 'prime'
require_relative '../lib/sequence_template'


class PrimeIndexCrash < OEISSequence
    def initialize
    @name = "Prime-Index Crash"
    @description = "a(n) = a(n-1) + n if composite. If a(n-1) is the k-th prime, a(n) = k. a(1)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + n if composite"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 1
    @pi_cache = []
    @prime_gen = Prime.each
    @prime_gen.next # Skip the 1st prime if we want, or just start
    # Wait, for n=2, we need p_2=3. Let's just create a new prime gen.
    @prime_gen = Prime.each
  end

  def pi(x)
    return 0 if x < 2
    # Simple sieve-based counting for efficiency
    if @pi_cache[x].nil?
      @pi_cache[x] = Prime.each(x).count
    end
    @pi_cache[x]
  end

  def compute_next
    @n += 1
    pn = @prime_gen.next
    
    if @current_a > 1 && @current_a.prime?
      # If it's the k-th prime, drop to k
      @current_a = pi(@current_a)
    else
      # Grow by the n-th prime
      @current_a += pn
    end
    
    @current_a
  end
end
