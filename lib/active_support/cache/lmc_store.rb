require 'active_support'
require 'localmemcache'
require 'concurrent/utility/monotonic_time'
require 'monitor'
require 'tmpdir'

class ActiveSupport::Cache::LmcStore < ActiveSupport::Cache::Store
  DEFAULT_DIR  = Dir.tmpdir
  DEFAULT_NAME = 'localmemcache'
  DEFAULT_SIZE = 16.megabytes # also the minimum size, as localmemcache is unreliable below this value

  def initialize(options = {})
    super options

    directory = options.fetch(:directory, DEFAULT_DIR)
    name      = options.fetch(:name, DEFAULT_NAME)
    size      = options.fetch(:size, DEFAULT_SIZE)

    data_store_options = {
      filename: Pathname.new(directory).join(name).to_s,
      size_mb:  [DEFAULT_SIZE, size].max / 1.megabyte
    }

    @data           = LocalMemCache.new(data_store_options)
    @max_prune_time = options[:max_prune_time] || 2
    @monitor        = Monitor.new
    @pruning        = false
  end

  def self.supports_cache_versioning?
    true
  end

  def clear(options = nil)
    synchronize do
      @data.clear
    end
  end

  def cleanup(options = nil)
    options = merged_options(options)
    instrument(:cleanup, size: used_bytes) do
      keys = synchronize { @data.keys }
      keys.each do |key|
        payload = @data[key]
        entry   = deserialize_entry(payload) if payload
        delete_entry(key, **options) if entry&.expired?
      end
    end
  end

  def prune(target_size, max_time = nil)
    return if pruning?
    @pruning = true
    begin
      start_time = Concurrent.monotonic_time
      cleanup
      instrument(:prune, target_size, from: used_bytes) do
        loop do
          key, _ = @data.random_pair
          delete_entry(key, **options)
          return if used_bytes <= target_size || (max_time && Concurrent.monotonic_time - start_time > max_time)
        end
      end
    ensure
      @pruning = false
    end
  end

  def pruning?
    @pruning
  end

  def increment(name, amount = 1, options = nil)
    modify_value(name, amount, options)
  end

  def decrement(name, amount = 1, options = nil)
    modify_value(name, -amount, options)
  end

  def delete_matched(matcher, options = nil)
    options = merged_options(options)
    instrument(:delete_matched, matcher.inspect) do
      matcher = key_matcher(matcher, options)
      keys    = synchronize { @data.keys }
      keys.each do |key|
        delete_entry(key, **options) if key.match(matcher)
      end
    end
  end

  def inspect # :nodoc:
    "#<#{self.class.name} entries=#{@data.size}, free=#{free_bytes}/#{total_bytes}, options=#{@options.inspect}>"
  end

  def synchronize(&block)
    @monitor.synchronize(&block)
  end

  def total_bytes
    @data.shm_status[:total_bytes]
  end

  def free_bytes
    @data.shm_status[:free_bytes]
  end

  def used_bytes
    total_bytes - free_bytes
  end

  private

  attr_reader :data

  def cached_size(key, payload)
    (key.to_s.bytesize + payload.bytesize) * 2
  end

  def read_entry(key, **options)
    entry = nil
    synchronize do
      payload = @data[key]
      entry   = deserialize_entry(payload) if payload
    end
    entry
  end

  def write_entry(key, entry, **options)
    payload = serialize_entry(entry)
    synchronize do
      cached_size = cached_size(key, payload)
      prune(total_bytes * 0.75, @max_prune_time) if free_bytes < cached_size
      @data[key] = payload
      true
    end
  end

  def delete_entry(key, **options)
    synchronize do
      payload = @data.delete(key)
      !!payload
    end
  end

  def modify_value(name, amount, options)
    options = merged_options(options)
    synchronize do
      if (num = read(name, options))
        num = num.to_i + amount
        write(name, num, options)
        num
      end
    end
  end
end
