# OEIS Discovery Framework

A modular Ruby framework for discovering, visualizing, and analyzing novel integer sequences for potential submission to the [Online Encyclopedia of Integer Sequences (OEIS)](https://oeis.org).

## 🚀 Key Discoveries

This framework has already uncovered several promising candidates for OEIS submission:

### 1. [Prime-Index Crash](sequences/high_potential/prime_index_crash.rb)
*   **The Rule:** `a(n) = a(n-1) + p_n` if composite; else `a(n) = pi(a(n-1))`.
*   **Significance:** Uses the Prime Number Theorem as a catastrophic reset mechanism. It accelerates upwards as $n \ln n$ until it hits a prime, where it drops to its own index, essentially dividing the value by $\ln(x)$. It exhibits dramatic climbs and "unpredictable" crashes.
*   **First 50:** 3, 2, 1, 8, 19, 8, 25, 44, 67, 19, 8, 45, 86, 129, 176, 229, 50, 111, 178, 249, 322...

### 2. [Popcount-Prime Walk](sequences/high_potential/popcount_prime_walk.rb)
*   **The Rule:** `a(n) = a(n-1) + popcount(n)` if composite; else `a(n) = abs(a(n-1) - n)`.
*   **Significance:** A perfectly balanced stochastic walk. It balances the logarithmic growth of binary density against linear resets. It stays bounded by $O(n)$ while vibrating chaotically.
*   **First 50:** 0, 1, 2, 1, 2, 3, 3, 4, 5, 4, 6, 9, 11, 2, 12, 16, 17, 0, 2, 17, 3, 18, 21, 25, 27, 30...

---

## 🛠 Usage

First, install the dependencies using Bundler:
```bash
bundle install
```

The framework is managed by a central CLI: `oeis_cli.rb`.

### List Sequences
```bash
bundle exec ruby oeis_cli.rb list
```

### Generate Terms
```bash
bundle exec ruby oeis_cli.rb generate prime_index_crash 100
```

### Analyze
```bash
bundle exec ruby oeis_cli.rb analyze prime_index_crash 1000
```

### Visualize
```bash
bundle exec ruby oeis_cli.rb plot popcount_prime_walk 500
bundle exec ruby oeis_cli.rb gui
```

### Generate b-file
```bash
bundle exec ruby oeis_cli.rb bfile prime_index_crash 10000
```

---

## 🧪 Contributing

Adding a new sequence is easy:
1.  Create a new file in `sequences/experimental/`.
2.  Inherit from `OEISSequence`.
3.  Implement `compute_next` and `reset_state`.
4.  Define metadata in `initialize`.

```ruby
class MyNewSequence < OEISSequence
  def initialize
    super
    @name = "My Sequence"
    @rank = "Experimental"
    @formula = "a(n) = a(n-1) + ..."
  end
  # ...
end
```

Generate the catalog to see your new sequence:
```bash
ruby oeis_cli.rb build-catalog
```

---

## 📜 Full Sequence Catalog
See the [CATALOG.md](CATALOG.md) for a complete list of all implemented sequences and their mathematical formulas.
