require 'json'
require 'fileutils'
require_relative 'version'

class OEISSequence
  attr_reader :name, :description, :author, :rank, :formula, :oeis_id, :terms

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
    @name = "Unnamed Sequence"
    @description = "No description."
    @author = "Anonymous"
    @rank = "Experimental"
    @formula = ""
    @terms = []
  end

  def cache_path
    FileUtils.mkdir_p('.cache')
    File.join('.cache', "#{self.class.to_s.downcase}.cache")
  end

  # HIGH PERFORMANCE BINARY STREAMING (v1.7.0)
  # [4 bytes: JSON Length] [N bytes: JSON State] [M bytes: Binary Terms (q*)]
  def save_cache
    state = {}
    instance_variables.each do |var|
      next if [:@terms, :@prime_gen].include?(var)
      state[var] = instance_variable_get(var)
    end
    json_blob = state.to_json
    
    File.open(cache_path, 'wb') do |f|
      f.write([json_blob.bytesize].pack('L')) # 4-byte header
      f.write(json_blob)
      f.write(@terms.pack('q*')) # raw 64-bit binary
    end
  end

  def load_cache(requested_count=nil)
    path = cache_path
    return reset_state unless File.exist?(path)
    
    begin
      File.open(path, 'rb') do |f|
        header = f.read(4)
        return reset_state unless header
        json_size = header.unpack1('L')
        
        # 1. Restore State
        state = JSON.parse(f.read(json_size))
        state.each { |k, v| instance_variable_set(k, v) }
        
        # 2. Selective Term Loading (Streaming)
        # Each 'q' term is 8 bytes.
        available_bytes = f.size - f.pos
        available_terms = available_bytes / 8
        
        # If we asked for 2k terms but file has 100k, only read what's needed
        to_read = requested_count ? [requested_count, available_terms].min : available_terms
        @terms = f.read(to_read * 8).unpack('q*')
      end
    rescue
      reset_state
    end
  end

  def generate(count)
    @terms ||= []
    load_cache(count) if @terms.empty?
    
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
    
    diffs = t.each_cons(2).map { |a, b| (a - b).abs }
    unique_ratio = t.uniq.size.to_f / t.size
    entropy = (diffs.sum.to_f / [t.max, 1].max) * 10
    
    # Simple Modern Heuristic
    score = (unique_ratio * 40) + [entropy, 40].min + 20
    { fitness_score: score.round(1), stats: { growth_type: "Chaotic" }, scoring: { activity: 20, novelty: 20, diversity: 20 } }
  end
end
