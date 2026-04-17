require 'prime'
require_relative '../../lib/sequence_template'

class InertialPrimeCrash < OEISSequence
  def initialize
    super
    @name = "Inertial Prime Crash"
    @description = "Accelerates linearly in current direction. Crashes and flips direction if prime, but only after a mandatory 10-step acceleration period."
    @author = "Andi"
    @rank = "High Potential"
    @formula = "a(n) = a(n-1) + dir * step; step resets and dir flips if a(n) is prime and n > last_n + 10"
    reset_state
  end

  def reset_state
    @current_a = 0
    @n = 0
    @step = 1
    @direction = 1
    @last_collision = 0
  end

  def compute_next
    @n += 1
    
    @current_a += (@direction * @step)
    
    # Collision condition: Prime AND at least 10 steps since last collision
    if @current_a.abs > 1 && @current_a.abs.prime? && (@n - @last_collision) > 10
      @direction *= -1
      @step = 1
      @last_collision = @n
    else
      @step += 1 # Continue accelerating
    end
    
    @current_a
  end
end
