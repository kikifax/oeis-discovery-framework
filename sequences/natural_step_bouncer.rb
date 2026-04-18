require 'prime'
require_relative '../lib/sequence_template'

class NaturalStepBouncer < OEISSequence
  def initialize
    super
    @name = "Natural-Step Bouncer"
    @description = "a(n) = a(n-1) + dir * n. If result <= 0, it mirrors (abs value) and dir=UP. If result is prime, dir flips. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = |a(n-1) + dir * n|; dir resets to 1 if hit zero, else flips if prime"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @direction = 1
  end

  def compute_next
    @n += 1
    
    # 1. Potential move
    next_v = @current_a + (@direction * @n)
    
    # 2. Check boundary (Mirror at zero)
    if next_v <= 0
      @current_a = next_v.abs
      @direction = 1 # Always bounce back UP
    else
      @current_a = next_v
      # 3. Check Prime Wall
      if @current_a > 1 && @current_a.prime?
        @direction *= -1
      end
    end
    
    @current_a
  end
  
  # Force recalculation for the new Mirror logic
  def generate(count)
    puts "[Station] Calculating MIRRORED Natural Step Bouncer..."
    super(count)
  end
end
