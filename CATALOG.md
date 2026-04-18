# OEIS Discovery Catalog

This catalog provides an index of all sequences implemented in this framework.

## High Potential Sequences

| Name | Formula | Doc |
| :--- | :--- | :--- |
| Base-N Digit Oscillator | `a(n) = a(n-1) + n; if count(digits_base_n(a(n), 1)) is prime, a(n) = floor(sqrt(a(n)))` | [View Full Report](docs/sequences/base_n_digit_oscillator.md) |
| Congruence Collision Oscillator | `a(n) = a(n-1) + dir * n; if a(n)%n is prime, a(n) %= n and dir flips` | [View Full Report](docs/sequences/congruence_collision.md) |
| Divisor-Balance Walk | `a(n) = a(n-1) + dir * n; dir flips and n resets to 1 if sigma0(a(n)) == sigma0(n)` | [View Full Report](docs/sequences/divisor_balance_walk.md) |
| Divisor-Residency Oscillator | `a(n) = a(n-1) + n; if sigma0(a(n)) % n is prime, a(n) = abs(a(n) - n^2)` | [View Full Report](docs/sequences/divisor_residency_oscillator.md) |
| GCD Prime-Step | `Add p_n if it doesn't divide a(n-1), otherwise divide by p_n` | [View Full Report](docs/sequences/gcd_prime_step.md) |
| Inertial Prime Crash | `a(n) = a(n-1) + dir * step; step resets and dir flips if a(n) is prime and n > last_n + 10` | [View Full Report](docs/sequences/inertial_prime_crash.md) |
| Liouville Prime Oscillator | `a(n) = a(n-1) + p_n if Omega(a(n-1)) is even, else |a(n-1) - p_n|` | [View Full Report](docs/sequences/liouville_oscillator.md) |
| Mirror Prime Bouncer | `a(n) = |a(n-1) + dir * p_n|; dir flips if prime or hit zero` | [View Full Report](docs/sequences/mirror_prime_bouncer.md) |
| Popcount-Prime Walk | `a(n) = a(n-1) + popcount(n)` | [View Full Report](docs/sequences/popcount_prime_walk.md) |
| Super-Prime Collision Oscillator | `a(n) = a(n-1) + dir * p_k; dir flips and k=1 if a(n) is Super-Prime` | [View Full Report](docs/sequences/prime_collision_oscillator.md) |
| Accelerated Prime Fibonacci | `a(n) = a(n-1) + a(n-2) + m if is_prime(a(n-1)) else |a(n-1)-a(n-2)|` | [View Full Report](docs/sequences/prime_hunter_fibonacci.md) |
| Prime-Index Crash | `a(n) = a(n-1) + n if composite` | [View Full Report](docs/sequences/prime_index_crash.md) |
| Prime-Step Bouncer | `a(n) = a(n-1) + dir * p_n; dir = -dir if is_prime(|a(n-1)|)` | [View Full Report](docs/sequences/prime_step_bouncer.md) |
| Prime-Step Divisibility Walk | `a(n) = a(n-1) + dir * p_n; dir = -dir if a(n) % n == 0` | [View Full Report](docs/sequences/prime_step_divisibility_walk.md) |
| Root-Square Bouncer | `a(n) = a(n-1) + dir * floor(sqrt(n)); dir flips if is_square(a(n))` | [View Full Report](docs/sequences/root_square_bouncer.md) |
| SPF-Sieve Oscillator | `a=a+dir*s; s++ if new; dir flips if a % spf(n) == 0` | [View Full Report](docs/sequences/sieve_residency_walk.md) |
| Slow-Grown Legendre | `a(n) = a(n-1) + SPF(n) if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|` | [View Full Report](docs/sequences/slow_grown_legendre.md) |
| Greedy Pioneer Walk | `a(n) = a(n-1) + dir * s; s++ if a(n) is new; dir flips if is_square(s)` | [View Full Report](docs/sequences/summand_history_walk.md) |
| Thue-Morse Prime Walk | `a(n) = a(n-1) + (-1)^popcount(a(n-1)) * p_n` | [View Full Report](docs/sequences/thue_morse_prime_walk.md) |

## Medium Potential Sequences

| Name | Formula | Doc |
| :--- | :--- | :--- |
| Legendre Mod-Reset | `a(n) = a(n-1) + n if not prime, else a(n-1) % (next_prime(n^2) - n^2 + 1)` | [View Full Report](docs/sequences/legendre_mod_reset.md) |
| Popcount Oscillator | `Step up by n if popcount(a(n-1)) is prime, down if composite, else stay` | [View Full Report](docs/sequences/popcount_oscillator.md) |
| Prime Tug-of-War | `a(n) = a(n-1) + p_n if that sum is prime, else abs(a(n-1) - LPF(a(n-1) + p_n))` | [View Full Report](docs/sequences/prime_tug_of_war.md) |
| Square-Free Tug | `Add n-th prime if square-free, else divide by largest square factor` | [View Full Report](docs/sequences/square_free_tug.md) |
| Totient Balance | `Step up if previous term is 'prime-heavy' (phi(n) > n/2), otherwise step down by the n-th prime` | [View Full Report](docs/sequences/totient_balance.md) |

## Experimental Sequences

| Name | Formula | Doc |
| :--- | :--- | :--- |
| Abundance Oscillator | `a(n) = a(n-1) + n if a(n-1) is deficient, a(n-1) - n if abundant, a(n-1) + n^2 if perfect` | [View Full Report](docs/sequences/abundance_oscillator.md) |
| Chaotic Prime Spring | `a(n) = a(n-1) + (n ^ waiting_time)` | [View Full Report](docs/sequences/chaotic_prime_spring.md) |
| Dynamic Log Balancer | `a(n) = a(n-1) + n if composite, else a(n-1) - floor(ln(a(n-1))^3)` | [View Full Report](docs/sequences/dynamic_log_balancer.md) |
| GCD Index-Crusher | `Add p_n if gcd(a(n-1), n)==1, else divide by gcd(a(n-1), n)` | [View Full Report](docs/sequences/gcd_index_crusher.md) |
| Legendre Bounder | `a(n) = a(n-1) - n if there is a prime in [n^2, n^2 + a(n-1)], else a(n-1) + n` | [View Full Report](docs/sequences/legendre_bounder.md) |
| Legendre Oscillator | `a(n) = a(n-1) + n if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|` | [View Full Report](docs/sequences/legendre_oscillator.md) |
| Log-Balanced Oscillator | `a(n) = a(n-1) + 1 if composite, else a(n-1) - floor(ln(a(n-1))^2)` | [View Full Report](docs/sequences/log_balanced_oscillator.md) |
| Prime Spring | `a(n) = a(n-1) + n` | [View Full Report](docs/sequences/prime_spring.md) |
| Prime Spring (+n) | `a(n) = a(n-1) + n` | [View Full Report](docs/sequences/prime_spring_plus_n.md) |
| Prime-Square Collapse | `a(n) = sqrt(V) if V = a(n-1) + p_n is a perfect square, else V` | [View Full Report](docs/sequences/prime_square_collapse.md) |
| Prime-Step Hunter | `a(n) = a(n-1) + n if a(n-1) is not prime, else |a(n-1) - p_n|` | [View Full Report](docs/sequences/prime_step_hunter.md) |
