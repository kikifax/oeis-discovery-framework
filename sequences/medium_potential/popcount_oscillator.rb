require 'prime'
require_relative '../../lib/sequence_template'

# THE POPCOUNT OSCILLATOR RULE:
# 1. We start at 0.
# 2. In each step n, we look at the previous number a(n-1).
# 3. We convert a(n-1) to binary and count how many "1"s it has (its PopCount).
# 4. We then decide our move based on that count:
#    - If PopCount is PRIME (e.g., 2, 3, 5 bits are set): Move UP by n.
#    - If PopCount is COMPOSITE (e.g., 4, 6, 8 bits are set): Move DOWN by n.
#    - If PopCount is 0 or 1 (neither prime nor composite): Move 0 steps.
#
# WHY THIS IS INTERESTING:
# It connects a number's additive value with its binary structure.
# Because primes are more common for small PopCounts (2, 3, 5, 7), the sequence tends to climb.
# But as it grows, the PopCount eventually hits 4 or 6, which triggers a downward crash.

class PopcountOscillator < OEISSequence
    def initialize
    @name = "Popcount Oscillator"
    @description = "Step up by n if popcount(a(n-1)) is prime, down if composite, else stay."
    @author = "Andi"
    @rank = "Medium Potential"
    @formula = "Step up by n if popcount(a(n-1)) is prime, down if composite, else stay"
    @oeis_id = "Pending"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
  end

  def popcount(n)
    n.abs.to_s(2).count('1')
  end

  def compute_next
    @n += 1
    bits = popcount(@current_a)
    
    if bits.prime?
      @current_a += @n
    elsif bits > 1 # must be composite
      @current_a = (@current_a - @n).abs
    else
      # 0 or 1 bits: no movement
    end
    
    @current_a
  end
end
