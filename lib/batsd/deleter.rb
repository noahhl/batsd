module Batsd
  #
  # Handle deletion for redis zsets and files written to disk
  #
  class Deleter

    # Create a new deleter
    #
    # * Establish the diskstore that will be used
    # * Establish the redis connection that will be needed
    #
    def initialize(options={})
      @options = options
      @redis = Batsd::Redis.new(options )
      @diskstore = Batsd::Diskstore.new(options[:root])
    end

    def delete(statistic)
      deletions = [statistic]
      deletions.each do |statistic|
        retentions = @options[:retentions].keys
        # first retention
        retentions.shift
        @redis.clear_key(statistic)
        @redis.remove_datapoint(statistic)

        # other retentions
        retentions.each do |retention|
          key = "#{statistic}:#{retention}:#{DATASTORE_VERSION}"
          @diskstore.delete(@diskstore.build_filename(key), :delete_empty_dirs => true)
        end
      end
      deletions
    end

  end
end
