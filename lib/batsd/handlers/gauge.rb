module Batsd
  #
  # Handles gauge measurements ("|g")
  #
  # Gauge measurements are never aggregated, and are
  # only stored on disk. They are written to disk immediately
  # upon receipt and without manipulation beyond correcting 
  # for sample rate (or more accurately, scale), if provided.
  #
  class Handler::Gauge < Handler
    
    # Set up a new handler to handle gauges
    #
    # * Set up a redis client
    # * Set up a diskstore client to write aggregates to disk
    #
    def initialize(options)
      @redis = Batsd::Redis.new(options)
      @diskstore = Batsd::Diskstore.new(options[:root])
      super
    end

    # Process an incoming gauge measurement
    #
    # * Normalize for sample rate provided
    # * Write current timestamp and value to disk
    # * Store the name of the datapoint in Redis 
    #
    def handle(key, value, sample_rate)
      @threadpool.queue Time.now.to_i, key, value, sample_rate do |timestamp, key, value, sample_rate|
        Batsd.logger.debug "Received #{key} #{value} #{sample_rate}" 
        if sample_rate
          value = value.to_f / sample_rate.gsub("@", "").to_f
        end
        value = "#{timestamp} #{value}"
        key   = "gauges:#{key}"
        @diskstore.append_value_to_file(@diskstore.build_filename(key), value)
        @redis.add_datapoint key
      end
    end

  end
end

