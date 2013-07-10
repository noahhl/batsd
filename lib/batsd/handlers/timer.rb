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
    # * Set up a filestore client to write aggregates to disk
    # * Initialize last flush timers to now
    #
    def initialize(options)
      now = Time.now.to_i

      @redis           = Batsd::Redis.new(options)
      @filestore       = Batsd::Filestore.init(options)
      @retentions      = options[:retentions].keys
      @flush_interval  = @retentions.first
      @active_timers   = {}
      @timers          = {}
      @last_flushes    = @retentions.inject({}){|l, r| l[r] = now; l }
      @fast_threadpool = Threadpool.new((options[:threadpool_size] || 100)/2)
      super
    end

    # Handle the key, value, and sample rate for a timer
    #
    # Store timers in a hashed array (<code>{a: [], b:[]}</code>) and
    # the set of timers we know about in a hash of nil values
    def handle(key, value, sample_rate)
      key = "timers:#{key}"
      if value
        @active_timers[key] ||= []
        @active_timers[key].push value.to_f
        @timers[key] = nil
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
      puts "Current threadpool queue for timers: #{@threadpool.size}" if ENV["VVERBOSE"]
      # Flushing is usually very fast, but always fix it so that the
      # entire thing is based on a constant start time
      # Saves on time syscalls too
      flush_start = Time.now.to_i
      
      n = @active_timers.size
      t = Benchmark.measure do 
        ts = (flush_start - flush_start % @flush_interval)
        timers = @active_timers.dup
        @active_timers = {}
        timers.each_slice(50) do |keys|
          @fast_threadpool.queue ts, keys do |timestamp, keys|
            keys.each do |key, values|
              puts "Storing #{values.size} values to redis for #{key} at #{timestamp}" if ENV["VVERBOSE"]
              # Store all the aggregates for the flush interval level
              count = values.count
              @redis.store_timer timestamp, "#{key}:mean", values.mean
              @redis.store_timer timestamp, "#{key}:count", count 
              @redis.store_timer timestamp, "#{key}:min", values.min
              @redis.store_timer timestamp, "#{key}:max", values.max
              @redis.store_timer timestamp, "#{key}:upper_90", values.percentile_90
              if count > 1
                @redis.store_timer timestamp, "#{key}:stddev", values.standard_dev
              end
              @redis.store_raw_timers_for_aggregations key, values
            end
          end
        end
      end
      puts "Flushed #{n} timers in #{t.real} seconds" if ENV["VERBOSE"]

      # If it's time for the latter aggregation to be written to disk, queue
      # those up
      @retentions.each_with_index do |retention, index|
        # First retention is always just flushed to redis on the flush interval
        next if index.zero?
        # Only if we're in need of a write to disk - if the next flush will be
        # past the threshold
        if (flush_start + @flush_interval) > @last_flushes[retention] + retention.to_i
          puts "Starting disk writing for timers@#{retention}" if ENV["VERBOSE"]
          t = Benchmark.measure do 
            ts = (flush_start - flush_start % retention.to_i)
            @timers.keys.each_slice(400) do |keys|
              @threadpool.queue ts, keys, retention do |timestamp, keys, retention|
                keys.each do |key|
                  values = @redis.extract_values_from_string("#{key}:#{retention}")
                  if values
                    values = values.collect(&:to_f)
                    puts "Writing the aggregates for #{values.count} values for #{key} at the #{retention} level to disk." if ENV["VVERBOSE"]
                    count = values.count
                    ["mean", "count", "min", "max", ["upper_90", "percentile_90"], ["stddev", "standard_dev"]].each do |aggregation|
                      if aggregation.is_a? Array
                        name = aggregation[0]
                        aggregation = aggregation[1]
                      else
                        name = aggregation
                      end
                      val = (count > 1 ? values.send(aggregation.to_sym) : values.first)
                      @filestore.append_value_to_file(@filestore.build_filename("#{key}:#{name}:#{retention}"), "#{timestamp} #{val}")
                    end
                  end
                end
              end
            end
            @last_flushes[retention] = flush_start
          end
          puts "#{Time.now}: Handled disk writing for timers@#{retention} in #{t.real}" if ENV["VERBOSE"]

          # If this is the last retention we're handling, flush the
          # times list to redis and reset it
          if retention == @retentions.last
            puts "Clearing the timers list. Current state is: #{@timers}" if ENV["VVERBOSE"]
            t = Benchmark.measure do 
              @redis.add_datapoint @timers.keys
              @timers = {}
            end
            puts "#{Time.now}: Flushed datapoints for timers in #{t.real}" if ENV["VERBOSE"]
          end

        end
      end

    end


  end
end
