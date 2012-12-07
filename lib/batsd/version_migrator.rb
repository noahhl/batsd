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
          puts retention
          decode_key = "v#{DATASTORE_VERSION} #{key}:#{retention}: #{target_operations.join("/")}"
          old_values = {}
          LEGACY_OPERATIONS.each do |new_name, old_name|
            old_values[new_name] = @diskstore.read("#{key}:#{old_name}:#{retention}", "0", Time.now.to_i.to_s, "1")
          end
          timestamps = old_values.collect{|k,v| v.collect{|a| a[:timestamp]}}.flatten.uniq.sort
          output = []
          express = old_values.collect{|k,v| v.length}.reject(&:zero?).collect{|t| t == timestamps.length}.find{|a| a == false}.nil?
          timestamps.each_with_index do |ts, i|
            combined_values = target_operations.collect do |operation|
              v2 = nil
              if v1 = old_values[operation.to_sym]
                if express
                  v2 = v1[i]
                else
                  v2 = v1.find{|v| v[:timestamp] == ts}
                end
                if v2
                  v2 = v2[:value]
                end
              end
              v2
            end
            if combined_values[0] && combined_values[0].to_i > 0
              output << "#{ts} #{combined_values.join("/")}"
            end
          end
          @diskstore.append_value_to_file(@diskstore.build_filename("#{key}:#{retention}:#{DATASTORE_VERSION}"), "#{output.join("\n")}", 0, decode_key)
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
