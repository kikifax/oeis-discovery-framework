# Base class for OEIS-style sequences
class OEISSequence
  attr_reader :name, :description, :author, :rank, :formula, :oeis_id, :terms

  def initialize
    @name = "Unnamed Sequence"
    @description = "No description provided."
    @author = "Anonymous"
    @rank = "Experimental"
    @formula = "Not defined"
    @oeis_id = "Pending"
    @terms = []
  end

  # This is the core logic that subclasses will override
  def compute_next
    raise NotImplementedError, "Subclasses must implement compute_next"
  end

  def generate(count)
    @terms = []
    reset_state
    count.times { @terms << compute_next }
    @terms
  end

  # Reset any internal state (counters, current values)
  def reset_state
    raise NotImplementedError, "Subclasses must implement reset_state"
  end

  def to_oeis_format
    @terms.join(", ")
  end

  def print_report
    puts "NAME: #{@name}"
    puts "RANK: #{@rank}"
    puts "FORMULA: #{@formula}"
    puts "DESC: #{@description}"
    puts "TERMS: #{to_oeis_format}"
  end
end
