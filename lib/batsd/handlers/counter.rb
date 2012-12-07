module Batsd
  #
  # Handles counter measurements ("|c")
  #
  # Counter measurements are summed together across 
  # aggregation intervals
  #
  class Handler::Counter < Handler

    # Set up a new handler to handle counters
    #
    # * Set up a redis client
    # * Set up a diskstore client to write aggregates to disk
    # * Initialize last flush timers to now
    #
    def initialize(options)
      @redis = Batsd::Redis.new(options)
      @diskstore = Batsd::Diskstore.new(options[:root])
      @counters = @active_counters = {}
      @retentions = options[:retentions].keys
      @flush_interval = @retentions.first
      now = Time.now.to_i
      @last_flushes = @retentions.inject({}){|l, r| l[r] = now; l }
      super
    end

    # Processes an incoming counter measurement
    #
    # * Normalize for sample rate provided
    # * Adds the value to any existing values by the same
    #   key and stores it in <code>@active_counters</code>
    # * Add the key and a nil value to <code>@counters</code>
    #   in order to track the set of counters that have been
    #   handled "recently". This is a relatively memory efficient,
    #   relatively fast way of storing a unique set of keys.
    #
    def handle(key, value, sample_rate)
      if sample_rate
        value = value.to_f / sample_rate.gsub("@", "").to_f
      end
      key   = "counters:#{key}"
      @active_counters[key] = @active_counters[key].to_i + value.to_i
      @counters[key] = nil
    end

    # Flushes the accumulated counters that are pending in
    # <code>@active_counters</code>.
    #
    # Each counter is pushed into the threadpool queue, which will
    # update all of the counters for all of the aggregations in Redis
    #
    # <code>flush</code> is also used to write the latter aggregations from
    # redis to disk. It does this by tracking the last time they were written.
    # If that was a sufficient time ago, the value will be retrieved from
    # redis, cleared, and written to disk in another thread.
    #
    # When the last level of aggregation (least granularity) is written,
    # the <code>@counters</code> will be flushed to the 'datapoints' set in
    # redis and reset
    #
    def flush
      Batsd.logger.debug "Current threadpool queue for counters: #{@threadpool.size}" 
      # Flushing is usually very fast, but always fix it so that the
      # entire thing is based on a constant start time
      # Saves on time syscalls too
      flush_start = Time.now.to_i

      n = @active_counters.size
      t = Benchmark.measure do 
        ts = (flush_start - flush_start % @flush_interval)
        counters = @active_counters.dup
        @active_counters = {}
        counters.each_slice(50) do |keys|
          @threadpool.queue ts, keys do |timestamp, keys|
            keys.each do |key, value|
              @redis.store_and_update_all_counters(timestamp, key, value)
            end
          end
        end
      end
      Batsd.logger.info "Flushed #{n} counters in #{t.real} seconds" 

      
      # If it's time for the latter aggregation to be written to disk, queue
      # those up
      @retentions.each_with_index do |retention, index|
        # First retention is always just flushed to redis on the flush interval
        next if index.zero?

        # Only if we're in need of a write to disk - if the next flush will be
        # past the threshold
        if (flush_start + @flush_interval) > @last_flushes[retention] + retention.to_i
          Batsd.logger.info "Starting disk writing for timers@#{retention}" 
          t = Benchmark.measure do 
            ts = (flush_start - flush_start % retention.to_i)
            counters = @counters.dup
            counters.keys.each_slice(400) do |keys|
              @threadpool.queue ts, keys, retention do |timestamp, keys, retention|
                keys.each do |key|
                  key = "#{key}:#{retention}"
                  value = @redis.get_and_clear_key(key)
                  if value
                    value = "#{ts} #{value}"
                    @diskstore.append_value_to_file(@diskstore.build_filename(key), value)
                  end
                end
              end
            end
            @last_flushes[retention] = flush_start
          end
          Batsd.logger.info "Handled disk writing for counters@#{retention} in #{t.real}" 

          # If this is the last retention we're handling, flush the
          # counters list to redis and reset it
          if retention == @retentions.last
            Batsd.logger.debug "Clearing the counters list. Current state is: #{@counters}" 
            t = Benchmark.measure do 
              @redis.add_datapoint @counters.keys
              @counters = {}
            end
            Batsd.logger.info "Flushed datapoints for counters in #{t.real}" 
          end
        end

      end

    end

  end
end
