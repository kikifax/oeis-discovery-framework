require 'prime'
require_relative '../../lib/sequence_template'

class MirrorPrimeBouncer < OEISSequence
  def initialize
    super
    @name = "Mirror Prime Bouncer"
    @description = "a(n) = a(n-1) + dir * p_n. If the result is negative, it mirrors at zero (absolute value) and direction becomes UP. Otherwise, if the result is prime, the direction flips. a(0)=0."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = |a(n-1) + dir * p_n|; dir flips if prime or hit zero"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @direction = 1
    @prime_gen = Prime.each
  end

  def compute_next
    @n += 1
    p_n = @prime_gen.next
    
    # 1. Tentative move
    next_v = @current_a + (@direction * p_n)
    
    # 2. The Zero Mirror (Boundary)
    if next_v < 0
      @current_a = next_v.abs
      @direction = 1 # Always go UP after hitting the floor
    else
      # 3. The Prime Wall (Internal Switch)
      @current_a = next_v
      if @current_a > 1 && @current_a.prime?
        @direction *= -1
      end
    end
    
    @current_a
  end
end
