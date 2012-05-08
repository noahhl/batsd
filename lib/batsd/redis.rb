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
      @redis = ::Redis.new(options[:redis] || {host: "127.0.0.1", port: 6379} )
      @redis.ping
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
        end
      end
    end

    
    # Returns the value of a key and then deletes it.
    #
    # TODO: This can be done in a single network request by rewriting
    # it as a redis script in Lua
    #
    def get_and_clear_counter(key)
      val = @redis.get key
      @redis.del key
      val
    end

    # Truncate a zset since a treshold time
    #
    def truncate_zset(key, since)
      @redis.zremrangebyscore key, 0, since
    end

    # Convenience accessor to members of datapoints set
    #
    def datapoints(with_gauges=true)
      datapoints = @redis.smembers "datapoints"
      unless with_gauges
        datapoints.reject!{|d| d.match /^gauge/ }
      end
      datapoints
    end

    # Stores a reference to the datapoint in 
    # the 'datapoints' set
    #
    def add_datapoint(key)
      if key.is_a? Array
        @redis.sadd "datapoints", *key
      else
        @redis.sadd "datapoints", key
      end
    end

  end
end
