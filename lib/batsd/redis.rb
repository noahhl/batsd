module Batsd
  # 
  # This is a thin wrapper around the redis client to
  # handle multistep procedures that could be executed using
  # Redis scripting
  #
  class Redis

    # Opens a new connection to the redis instance specified 
    # in the configuration or localhost:6379
    #
    def initialize(options)
      @redis = ::Redis.new(options[:redis] || {:host => "127.0.0.1", :port => 6379} )
      @redis.ping
      if @redis.info['redis_version'].to_f < 2.5
        abort "You need Redis 2.6+ in order to run Batsd. See http://redis.io/ for details."
      end
      @retentions = options[:retentions].keys
    end
    
    # Expose the redis client directly
    def client
      @redis
    end

    # Store a counter measurement for each of the specified retentions
    #
    # * For shortest retention (where timestep == flush interval), add the
    #   value and timestamp to the appropriate zset
    #
    # * For longer retention intervals, increment the appropriate counter
    #   by the value specified.
    #
    # TODO: This can be done in a single network request by rewriting
    # it as a redis script in Lua
    #
    def store_and_update_all_counters(timestamp, key, value)
      @retentions.each_with_index do |t, index|
        if index.zero?
          @redis.zadd key, timestamp, "#{timestamp}<X>#{value}"
        else index.zero?
          @redis.incrby "#{key}:#{t}", value
          @redis.expire "#{key}:#{t}", t.to_i * 2
        end
      end
    end

    # Store a timer to a zset
    #
    def store_timer(timestamp, key, value)
      @redis.zadd key, timestamp, "#{timestamp}<X>#{value}"
    end

    # Store unaggregated, raw timer values in bucketed keys
    # so that they can actually be aggregated "raw"
    #
    # The set of tiemrs are stored as a single string key delimited by 
    # \x0. In benchmarks, this is more efficient in memory by 2-3x, and
    # less efficient in time by ~10%
    #
    # TODO: can this be done more efficiently with redis scripting?
    def store_raw_timers_for_aggregations(key, values)
      @retentions.each_with_index do |t, index|
        next if index.zero?
        @redis.append "#{key}:#{t}", "<X>#{values.join("<X>")}"
        @redis.expire "#{key}:#{t}", t.to_i * 2
      end
    end
    
    # Returns the value of a key and then deletes it.
    def get_and_clear_key(key)
      cmd = <<-EOF
        local str = redis.call('get', KEYS[1])
        redis.call('del', KEYS[1])
        return str
      EOF
      @redis.eval(cmd, 1, key.to_sym)
    end
    
    # Create an array out of a string of values delimited by <X>
    def extract_values_from_string(key)
      cmd = <<-EOF
        local t={} ; local i=1
        local str = redis.call('get', KEYS[1])
        if (str) then
          for s in string.gmatch(str, "([^".."<X>".."]+)") do
            t[i] = s 
            i = i + 1
          end
          redis.call('del', KEYS[1])
        end
        return t
      EOF
      @redis.eval(cmd, 1, key.to_sym)
    end

    # Truncate a zset since a treshold time
    #
    def truncate_zset(key, since)
      @redis.zremrangebyscore key, 0, since
    end

    # Return properly formatted values from the zset
    def values_from_zset(metric, begin_ts, end_ts)
      begin
        values = @redis.zrangebyscore(metric, begin_ts, end_ts)
        values.collect{|val| ts, val = val.split("<X>"); {:timestamp => ts, :value => val } }
      rescue
        []
      end
    end

    # Convenience accessor to members of datapoints set
    #
    def datapoints(with_gauges=true)
      datapoints = @redis.smembers "datapoints"
      unless with_gauges
        datapoints.reject!{|d| (d.match(/^gauge/) rescue false) }
      end
      datapoints
    end

    # Stores a reference to the datapoint in 
    # the 'datapoints' set
    #
    def add_datapoint(key)
      @redis.sadd "datapoints", key
    end

  end
end
