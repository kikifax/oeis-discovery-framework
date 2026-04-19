require 'json'
require 'fileutils'
require_relative 'version'

class OEISSequence
  attr_reader :name, :description, :author, :rank, :formula, :terms

  PRIME_CACHE = []
  PRIME_GEN = Prime.each

  def self.get_prime(k)
    return PRIME_CACHE[k-1] if k <= PRIME_CACHE.size
    while PRIME_CACHE.size < k
      PRIME_GEN.next.tap { |p| PRIME_CACHE << p }
    end
    PRIME_CACHE[k-1]
  end

  def initialize
    @name = "Unnamed"
    @description = ""
    @author = "Andi"
    @rank = "Experimental"
    @formula = ""
    @terms = []
    reset_state
  end

  def cache_path
    FileUtils.mkdir_p('.cache')
    File.join('.cache', "#{self.class.to_s.downcase}.cache")
  end

  # SIMPLE BINARY FORMAT (v1.8.8)
  # [Raw 64-bit Binary Terms (q*)]
  def save_cache
    File.open(cache_path, 'wb') { |f| f.write(@terms.pack('q*')) }
  end

  def load_cache(count=nil)
    path = cache_path
    return reset_state unless File.exist?(path)
    
    begin
      raw = File.read(path)
      return reset_state if raw.empty?
      
      all_terms = raw.unpack('q*')
      # We must reconstruct the state by 'replaying' or setting counters
      @terms = count ? all_terms.first(count) : all_terms
      
      # Reconstruct state variables based on how many terms we loaded
      reconstruct_state(@terms)
    rescue
      reset_state
    end
  end

  def reconstruct_state(terms)
    reset_state
    # Subclasses can override this, but standard is to just set current value to last term
    if terms.any?
      @current_a = terms.last
      @n = terms.size
    end
  end

  def generate(count)
    @terms ||= []
    load_cache if @terms.empty?
    
    if @terms.size < count
      needed = count - @terms.size
      needed.times { @terms << compute_next }
      save_cache
    end
    @terms[0...count]
  end

  def analyze(count)
    t = generate(count)
    return {fitness_score: 0} if t.empty?
    unique_ratio = t.uniq.size.to_f / t.size
    { 
      fitness_score: (unique_ratio * 100).round(1), 
      stats: { growth_type: "Oscillating" },
      scoring: { activity: 25, novelty: 25, diversity: 25 }
    }
  end
end
