module Batsd
  class VersionMigrator
    class NoMigrationPath < Exception; end; 
    def initialize(config)
      @config = config
      @redis = Batsd::Redis.new(@config)
      @diskstore = Batsd::Diskstore.new(@config[:root])
    end
    
    def migrate_to_v2(key, retentions=@config[:retentions])
      if key.match(/timers:/)
        migrate_timer_to_v2(key, retentions)
      else
        raise NoMigrationPath
      end
    end

    private
      LEGACY_OPERATIONS = {count: "count", mean: "mean", min: "min", max: "max", stddev: "stddev", percentile_90: "upper_90"}
      def migrate_timer_to_v2(key, retentions)
        @handler = Batsd::Handler::Timer.new(@config)
        target_operations = ["count"] + (@config[:operations] || Batsd::STANDARD_OPERATIONS)
        retentions.each_with_index do |(retention,v), i|
          next if i.zero?
          old_values = {}
          LEGACY_OPERATIONS.each do |new_name, old_name|
            old_values[new_name] = @diskstore.read("#{key}:#{old_name}:#{retention}", 0, Time.now.to_i, true)
          end

          # 1) Find unique set of ordered timestamps in old data
          # 2) For each timestamp, construct a new measurement with all of them
          # and write it to disk
          # 3) Add the old data to a list to be deleted from disk
          #
          #new_values = {}
          #target_operations.each do |operation|
          #  new_values[operation] = old_values[operation]
          #end

        end
      end

  end
end
