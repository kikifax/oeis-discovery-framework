require 'prime'
require_relative '../lib/sequence_template'

class SuperPrimeCollisionOscillator < OEISSequence
  def initialize
    super
    @name = "Super-Prime Collision Oscillator"
    @description = "Moves by p_k in current direction. K increments every step, but resets to 1 and flips direction when a(n) hits a Super-Prime (prime whose index is also prime)."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * p_k; dir flips and k=1 if a(n) is Super-Prime"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @k = 1
    @direction = 1
    @pi_cache = {}
  end

  def pi(x)
    return 0 if x < 2
    @pi_cache[x] ||= Prime.each(x).count
  end

  def is_super_prime?(x)
    return false if x < 3
    return false unless x.prime?
    idx = pi(x)
    idx.prime?
  end

  # Helper to get k-th prime
  def get_prime(k)
    @cache ||= []
    while @cache.size < k
      @cache_gen ||= Prime.each
      @cache << @cache_gen.next
    end
    @cache[k-1]
  end

  def compute_next
    @n += 1
    
    step = get_prime(@k)
    @current_a += (@direction * step)
    
    if @current_a.abs > 2 && is_super_prime?(@current_a.abs)
      @direction *= -1 
      @k = 1           
    else
      @k += 1          
    end
    
    @current_a
  end
end
