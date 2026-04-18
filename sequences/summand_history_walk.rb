require 'set'
require_relative '../lib/sequence_template'

class GreedyPioneerWalk < OEISSequence
  def initialize
    super
    @name = "Greedy Pioneer Walk"
    @description = "Moves by summand 's' in current direction. s increments whenever a new number is discovered. Direction flips whenever the summand 's' is a perfect square. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * s; s++ if a(n) is new; dir flips if is_square(s)"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @s = 1
    @direction = 1
    @history = Set.new([0])
  end

  def is_square?(x)
    return false if x < 0
    root = Math.sqrt(x).to_i
    root * root == x
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
    
    # The Switch: Square-based thinning
    if is_square?(@s)
      @direction *= -1
    end
    
    @current_a
  end
end
