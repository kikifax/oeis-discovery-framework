require 'set'
require 'prime'
require_relative '../lib/sequence_template'

class SieveResidencyWalk < OEISSequence
  def initialize
    super
    @name = "SPF-Sieve Oscillator"
    @description = "Moves by summand 's' in current direction. s increments whenever a new number is discovered. Direction flips whenever the current term a(n) is divisible by the smallest prime factor of the index n. a(0)=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a=a+dir*s; s++ if new; dir flips if a % spf(n) == 0"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 1
    @s = 1
    @direction = 1
    @history = Set.new([1])
  end

  def spf(x)
    return 1 if x <= 1
    Prime.prime_division(x).map(&:first).min
  end

  def compute_next
    @n += 1
    
    # Move
    @current_a += (@direction * @s)
    
    # Discovery
    unless @history.include?(@current_a)
      @s += 1
      @history << @current_a
    end
    
    # The Switch: SPF-based thinning
    if (@current_a % spf(@n)) == 0
      @direction *= -1
    end
    
    @current_a
  end
end
