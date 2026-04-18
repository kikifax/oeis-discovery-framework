require_relative '../lib/sequence_template'

class RootSquareBouncer < OEISSequence
  def initialize
    super
    @name = "Root-Square Bouncer"
    @description = "a(n) = a(n-1) + dir * floor(sqrt(n)). The direction flips whenever a(n) is a perfect square. a(0)=2."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * floor(sqrt(n)); dir flips if is_square(a(n))"
    reset_state
  end

  def reset_state
    @current_a = 2
    @n = 0
    @direction = 1
  end

  def is_square?(n)
    return false if n < 0
    return true if n == 0
    root = Math.sqrt(n).to_i
    root * root == n
  end

  def compute_next
    @n += 1
    
    step = Math.sqrt(@n).floor
    @current_a += (@direction * step)
    
    if is_square?(@current_a)
      @direction *= -1
    end
    
    @current_a
  end
end
