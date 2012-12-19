module Batsd
  #
  # Handles timer measurements ("|c")
  #
  # Timer measurements are aggregated in various ways across 
  # aggregation intervals
  #
  class Handler::Timer < Handler

    # Set up a new handler to handle timers
    #
    # * Set up a redis client
    # * Set up a diskstore client to write aggregates to disk
    # * Initialize last flush timers to now
    #
    def initialize(options)
      @retentions = options[:retentions].keys
      @operations = options[:operations] || STANDARD_OPERATIONS 

      @slots = @retentions.collect{|r| (r.to_f / @retentions.first).floor}
      @timers =  @slots.collect{|s| s.times.collect{|f| {} } }
      @active_timers = {}
      @current_slots = @retentions.collect{|r| -1}
      @key_slot_map = {}

      super
    end

    # Handle the key, value, and sample rate for a timer
    #
    # Store timers in a hashed array (<code>{a: [], b:[]}</code>) and
    # the set of timers we know about in a hash of nil values
    def handle(key, value, sample_rate)
      key = "timers:#{key}"
      if value
        value = value.to_f
        @retentions.size.times do |i|
          slot = @key_slot_map[key] ||= key.hash % @slots[i]
          @timers[i][slot][key] ||= []
          @timers[i][slot][key].push value
        end
      end
    end

    # Flush timers to redis and disk.
    #
    # 1) At every flush interval, flush to redis and clear active timers. Also
    #    store raw values for usage later.
    # 2) If time since last disk write for a given aggregation, flush to disk.
    # 3) If flushing the terminal aggregation, flush the set of datapoints to
    #    Redis and reset that tracking in process.
    #
    def flush
      # Flushing is usually very fast, but always fix it so that the
      # entire thing is based on a constant start time
      # Saves on time syscalls too
      flush_start = Time.now.to_i
      
      @retentions.each_with_index do |retention, index|

        @current_slots[index] += 1 
        @current_slots[index] = 0 if @current_slots[index] ==  @slots[index] 
        

        ts = (flush_start - flush_start % retention)
        timers = @timers[index][@current_slots[index]].dup
        @timers[index][@current_slots[index]] = {}


        if index.zero?
          timers.each_slice(50) do |keys|
            threadpool.queue ts, keys do |timestamp, keys|
              keys.each do |key, values|
               Batsd.logger.debug "Storing #{values.size} values to redis for #{key} at #{timestamp}" 

                # Store all the aggregates for the flush interval level
                count = values.count

                combined_values = [count] + @operations.collect do |aggregation|
                  count > 1 ? values.send(aggregation.to_sym) : values.first
                end

                if count > 0 
                  combined_values = combined_values.join("/")
                  redis.store_timer timestamp, key, combined_values
                end

              end
            end
          end
        else
          timers.each_slice(400) do |keys|
            threadpool.queue ts, keys, retention do |timestamp, keys, retention|
              keys.each do |key, values|
                if values
                  count = values.count

                  Batsd.logger.debug "Writing the aggregates for #{values.count} values for #{key} at the #{retention} level to disk." 
                  combined_values = [count] + @operations.collect do |aggregation|
                    count > 1 ? values.send(aggregation.to_sym) : values.first
                  end

                  if count > 0 
                    combined_values = combined_values.join("/")
                    decode_key = "v#{DATASTORE_VERSION} #{key}:#{retention}: #{(["count"] + @operations).join("/")}"
                    diskstore.append_value_to_file(diskstore.build_filename("#{key}:#{retention}:#{DATASTORE_VERSION}"), "#{timestamp} #{combined_values}", 0, decode_key)
                  end

                end
              end
            end
          end

          # If this is the last retention we're handling, flush the
          # times list to redis and reset it
          if retention == @retentions.last
            redis.add_datapoint timers.keys
          end

        end

      end

    end


  end
end
