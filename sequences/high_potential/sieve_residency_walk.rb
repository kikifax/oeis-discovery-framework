require 'set'
require_relative '../../lib/sequence_template'

class SieveResidencyWalk < OEISSequence
  def initialize
    super
    @name = "Sieve-Residency Walk"
    @description = "a(n) = a(n-1) + s. If the sum is not divisible by any previous term > 1, a(n) = floor(a(n)/2). Otherwise, s increments. a(0)=2, s=1."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "v = a(n-1) + s; if v % any(history > 1) == 0: a(n) = v, s++; else: a(n) = v/2"
    reset_state
  end

  def reset_state
    @current_a = 2
    @n = 0
    @s = 1
    @history = Set.new([2])
  end

  def compute_next
    @n += 1
    
    v = @current_a + @s
    
    # Check if any element in history (excluding 1) divides the current sum
    is_divisible = @history.any? { |h| h > 1 && (v % h == 0) }
    
    if is_divisible
      # Familiar territory: Grow and boost summand
      @current_a = v
      @s += 1
    else
      # Foreign territory: Half and keep summand
      @current_a = (v / 2).floor
    end
    
    @history << @current_a
    @current_a
  end
end
