require 'prime'
require_relative '../lib/sequence_template'

class BaseNDigitOscillator < OEISSequence
  def initialize
    super
    @name = "Base-N Digit Oscillator"
    @description = "a(n) = a(n-1) + n. If the count of '1's in the base-n representation of a(n) is prime, a(n) = sqrt(a(n))."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + n; if count(digits_base_n(a(n), 1)) is prime, a(n) = floor(sqrt(a(n)))"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 1
  end

  def count_ones_in_base(num, base)
    return 0 if num == 0
    return 0 if base < 2
    
    count = 0
    temp = num
    while temp > 0
      count += 1 if (temp % base) == 1
      temp /= base
    end
    count
  end

  def compute_next
    @n += 1
    @current_a += @n
    
    # Check the condition in base n
    ones_count = count_ones_in_base(@current_a, @n)
    
    if ones_count > 1 && ones_count.prime?
      # Catastrophic crash
      @current_a = Math.sqrt(@current_a).floor
    end
    
    @current_a
  end
end
