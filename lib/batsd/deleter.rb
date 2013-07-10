module Batsd
  #
  # Handle deletion for redis zsets and files written to disk
  #
  class Deleter

    # Create a new deleter
    #
    # * Establish the filestore that will be used
    # * Establish the redis connection that will be needed
    #
    def initialize(options={})
      @options = options
      @redis = Batsd::Redis.new(options)
      @filestore = Batsd::Filestore.init(options)
    end

    def delete(statistic)
      if statistic.match(/^timers:/)
        # Fully specified key
        if statistic.match(/^timers:.*:(mean|count|min|max|stddev|upper_90)/) 
          deletions = [statistic]
        else
          # Only statistic, not mean/min/max. Delete all of them
          deletions = %w(mean count min max stddev upper_90).collect{|a| "#{statistic}:#{a}"}
        end
      else
        deletions = [statistic]
      end
      deletions.each do |statistic|
        retentions = @options[:retentions].keys
        # first retention
        retentions.shift
        @redis.clear_key(statistic)
        @redis.remove_datapoint(statistic)

        # other retentions
        retentions.each do |retention|
          key = "#{statistic}:#{retention}"
          @filestore.delete(@filestore.build_filename(key), delete_empty_dirs: true)
        end
      end
      deletions
    end

  end
end
