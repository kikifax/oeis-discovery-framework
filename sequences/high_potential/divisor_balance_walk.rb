require 'prime'
require_relative '../../lib/sequence_template'

class DivisorBalanceWalk < OEISSequence
  def initialize
    super
    @name = "Divisor-Balance Walk"
    @description = "Grows by current step size in current direction. Step size resets and direction flips if a(n) and n have the same number of divisors."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * n; dir flips and n resets to 1 if sigma0(a(n)) == sigma0(n)"
    reset_state
  end

  def reset_state
    @current_a = 1
    @n = 1
    @direction = 1
    @step_size = 1
  end

  def sigma0(n)
    return 1 if n.abs <= 1
    factors = Prime.prime_division(n.abs)
    factors.reduce(1) { |prod, (_, e)| prod * (e + 1) }
  end

  def compute_next
    @n += 1
    @step_size += 1
    
    @current_a += (@direction * @step_size)
    
    # The condition that thins out over time
    if sigma0(@current_a) == sigma0(@n)
      @direction *= -1
      @step_size = 1 # Reset the acceleration
    end
    
    @current_a
  end
end
