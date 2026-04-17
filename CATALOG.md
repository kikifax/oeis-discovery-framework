# OEIS Discovery Catalog

This catalog is auto-generated and lists all sequences currently in the discovery framework.

## High Potential Sequences

| Key | Name | Formula | Description |
| :--- | :--- | :--- | :--- |
| `gcd_prime_step` | GCD Prime-Step | `Add p_n if it doesn't divide a(n-1), otherwise divide by p_n` | Add p_n if it doesn't divide a(n-1), otherwise divide by p_n. |
| `liouville_oscillator` | Liouville Prime Oscillator | `a(n) = a(n-1) + p_n if Omega(a(n-1)) is even, else |a(n-1) - p_n|` | a(n) = a(n-1) + p_n if Omega(a(n-1)) is even, else |a(n-1) - p_n|. a(0)=1. |
| `popcount_prime_walk` | Popcount-Prime Walk | `a(n) = a(n-1) + popcount(n)` | a(n) = a(n-1) + popcount(n). If prime, a(n) = abs(a(n-1) - n). a(0)=1. |
| `prime_index_crash` | Prime-Index Crash | `a(n) = a(n-1) + n if composite` | a(n) = a(n-1) + n if composite. If a(n-1) is the k-th prime, a(n) = k. a(1)=1. |
| `slow_grown_legendre` | Slow-Grown Legendre | `a(n) = a(n-1) + SPF(n) if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|` | a(n) = a(n-1) + SPF(n) if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|. a(0)=1. |

## Medium Potential Sequences

| Key | Name | Formula | Description |
| :--- | :--- | :--- | :--- |
| `legendre_mod_reset` | Legendre Mod-Reset | `a(n) = a(n-1) + n if not prime, else a(n-1) % (next_prime(n^2) - n^2 + 1)` | a(n) = a(n-1) + n if not prime, else a(n-1) % (next_prime(n^2) - n^2 + 1). a(0)=1. |
| `popcount_oscillator` | Popcount Oscillator | `Step up by n if popcount(a(n-1)) is prime, down if composite, else stay` | Step up by n if popcount(a(n-1)) is prime, down if composite, else stay. |
| `prime_tug_of_war` | Prime Tug-of-War | `a(n) = a(n-1) + p_n if that sum is prime, else abs(a(n-1) - LPF(a(n-1) + p_n))` | a(n) = a(n-1) + p_n if that sum is prime, else abs(a(n-1) - LPF(a(n-1) + p_n)). |
| `square_free_tug` | Square-Free Tug | `Add n-th prime if square-free, else divide by largest square factor` | Add n-th prime if square-free, else divide by largest square factor. |
| `totient_balance` | Totient Balance | `Step up if previous term is 'prime-heavy' (phi(n) > n/2), otherwise step down by the n-th prime` | Step up if previous term is 'prime-heavy' (phi(n) > n/2), otherwise step down by the n-th prime. |

## Experimental Sequences

| Key | Name | Formula | Description |
| :--- | :--- | :--- | :--- |
| `abundance_oscillator` | Abundance Oscillator | `a(n) = a(n-1) + n if a(n-1) is deficient, a(n-1) - n if abundant, a(n-1) + n^2 if perfect` | a(n) = a(n-1) + n if a(n-1) is deficient, a(n-1) - n if abundant, a(n-1) + n^2 if perfect. a(0)=1. |
| `chaotic_prime_spring` | Chaotic Prime Spring | `a(n) = a(n-1) + (n ^ waiting_time)` | a(n) = a(n-1) + (n ^ waiting_time). If prime, a(n) = a(n) % (floor(sqrt(a(n))) + 1). |
| `dynamic_log_balancer` | Dynamic Log Balancer | `a(n) = a(n-1) + n if composite, else a(n-1) - floor(ln(a(n-1))^3)` | a(n) = a(n-1) + n if composite, else a(n-1) - floor(ln(a(n-1))^3). a(0)=1. |
| `gcd_index_crusher` | GCD Index-Crusher | `Add p_n if gcd(a(n-1), n)==1, else divide by gcd(a(n-1), n)` | Add p_n if gcd(a(n-1), n)==1, else divide by gcd(a(n-1), n). |
| `legendre_bounder` | Legendre Bounder | `a(n) = a(n-1) - n if there is a prime in [n^2, n^2 + a(n-1)], else a(n-1) + n` | a(n) = a(n-1) - n if there is a prime in [n^2, n^2 + a(n-1)], else a(n-1) + n. a(0)=1. |
| `legendre_oscillator` | Legendre Oscillator | `a(n) = a(n-1) + n if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|` | a(n) = a(n-1) + n if composite, else |a(n-1) - n * (next_prime(n^2) - n^2)|. a(0)=1. |
| `log_balanced_oscillator` | Log-Balanced Oscillator | `a(n) = a(n-1) + 1 if composite, else a(n-1) - floor(ln(a(n-1))^2)` | a(n) = a(n-1) + 1 if composite, else a(n-1) - floor(ln(a(n-1))^2). a(0)=1. |
| `prime_spring` | Prime Spring | `a(n) = a(n-1) + n` | a(n) = a(n-1) + n. If prime, a(n) = a(n) % (steps_since_last_prime * floor(ln(a(n))) + 1). |
| `prime_spring_plus_n` | Prime Spring (+n) | `a(n) = a(n-1) + n` | a(n) = a(n-1) + n. If a(n) is prime, a(n) = a(n) % (waiting_time * floor(ln(a(n))) + 1). |
| `prime_square_collapse` | Prime-Square Collapse | `a(n) = sqrt(V) if V = a(n-1) + p_n is a perfect square, else V` | a(n) = sqrt(V) if V = a(n-1) + p_n is a perfect square, else V. a(0)=0. |
| `prime_step_hunter` | Prime-Step Hunter | `a(n) = a(n-1) + n if a(n-1) is not prime, else |a(n-1) - p_n|` | a(n) = a(n-1) + n if a(n-1) is not prime, else |a(n-1) - p_n|. a(0)=1. |
