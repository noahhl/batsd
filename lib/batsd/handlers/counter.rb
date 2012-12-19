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
      @retentions = options[:retentions].keys
      @slots = @retentions.collect{|r| (r.to_f / @retentions.first).floor}
      @counters =  @slots.collect{|s| s.times.collect{|f| {} } }
      @current_slots = @retentions.collect{|r| -1}
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
      @retentions.size.times do |i|
        slot = key.hash % @slots[i]
        @counters[i][slot][key] = @counters[i][slot][key].to_i + value.to_i
      end
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

      # Flushing is usually very fast, but always fix it so that the
      # entire thing is based on a constant start time
      # Saves on time syscalls too
      flush_start = Time.now.to_i
      
      @retentions.each_with_index do |retention, index|
        @current_slots[index] += 1 
        @current_slots[index] = 0 if @current_slots[index] ==  @slots[index] 
          
        ts = (flush_start - flush_start % retention.to_i)
        counters = @counters[index][@current_slots[index]].dup
        @counters[index][@current_slots[index]] = {}

        if index.zero?
          counters.each_slice(50) do |keys|
            threadpool.queue ts, keys do |timestamp, keys|
              keys.each do |key, value|
                redis.client.zadd key, timestamp, "#{timestamp}<X>#{value}"
              end
            end
          end
        else
          counters.each_slice(100) do |keys|
            threadpool.queue ts, keys, retention do |timestamp, keys, retention|
              keys.each do |key, value|
                key = "#{key}:#{retention}"
                if value
                  value = "#{ts} #{value}"
                  decode_key = "v#{DATASTORE_VERSION} #{key}"
                  diskstore.append_value_to_file(diskstore.build_filename(key), value, 0, decode_key)
                end
              end
            end
          end
        end

        # If this is the last retention we're handling, flush the
        # counters list to redis and reset it
        if retention == @retentions.last
          redis.add_datapoint counters.keys
        end

      end

    end

  end
end
