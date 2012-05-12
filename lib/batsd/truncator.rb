module Batsd
  #
  # Handle truncation for redis zsets and files written to disk
  #
  class Truncator

    # Create a new truncator
    #
    # * Establish the diskstore that will be used
    # * Establish the redis connection that will be needed
    #
    def initialize(options={})
      @options = options
      @retentions = options[:retentions].keys
      @redis = Batsd::Redis.new(options )
      @diskstore = Batsd::Diskstore.new(options[:root])
    end

    # Perform a truncation run. Sole argument is the aggregation level to be
    # truncated (e.g., 10, 60, 600)
    #
    # If the retention interval is the first one, it's assumed to stored in
    # redis, and the truncation is performed by zremrangebyscore on the zsets.
    #
    # For other retention intervals, it's assumed that they are stored on disk.
    # Each key is truncated on disk.
    #
    # In neither case are gauges included for truncation.
    #
    def run(retention)
      min_ts = Time.now.to_i - (@options[:retentions][retention] * retention)
      keys = @redis.datapoints(with_gauges=false)
      keys = keys.collect do |k|
        if k.match /^timer/
          ["mean", "min", "max", "upper_90", "stddev", "count"].collect{|a| "#{k}:#{a}"}
        else
          k
        end
      end.flatten

      if retention == @retentions.first
        # First retention is stored in redis, so just need to truncate the zset
        # TODO: can we do this in bulk with lua script?
        keys.each { |key| @redis.truncate_zset(key, min_ts) }
      else
        # Stored on disk
        keys.each do |key|
          key = "#{key}:#{retention}"
          @diskstore.truncate(@diskstore.build_filename(key), min_ts)
        end
      end
    end

  end
end
