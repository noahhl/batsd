require 'json'
module Batsd
  # Makes data from statsd available over a TCP socket
  module Server
    # access the server config
    def self.config
      @config
    end

    # Set the config for the server
    def self.config=(config)
      @config=config
    end
   
    # Set up a redis and diskstore instance per connection
    # so they don't step on each other. Since redis commands
    # are happening in a deferrable, intentionally not using EM-redis
    def post_init
      Batsd.logger.warn "batsd server ready and waiting on #{Batsd::Server.config[:port]} to ship data upon request\n"
      @redis = Batsd::Redis.new(Batsd::Server.config)
      @diskstore = Batsd::Diskstore.new(Batsd::Server.config[:root])
    end
    
    # Handle a command received over the server port and return
    # the datapoints, values, or a PONG as requested.
    def receive_data(msg)  
      msg.split("\n").each do |row|
        begin
          msg_split = row.split(" ")
          command = msg_split[0]

          return unless command
          case
            when command.match(/available/i)
              EM.defer { send_data "#{JSON(@redis.datapoints)}\n" }
            when command.match(/values/i)
              EM.defer do
                 command, metric, begin_time, end_time = msg_split
                 datapoints, interval = [], 0

                 if metric.match(/^gauge/)
                   datapoints = @diskstore.read(metric, begin_time, end_time)
                 else

                   Batsd::Server.config[:retentions].each_with_index do |retention, index|
                     if (index != Batsd::Server.config[:retentions].count - 1) && (Time.now.to_i - (retention[0] * retention[1]) > begin_time.to_i)
                       next
                     end
                     interval = retention[0]

                     if index.zero?
                       datapoints = @redis.values_from_zset(metric, begin_time, end_time)
                       break
                     else

                       if metric.match(/^timers:/)
                         if metric.match(/^timers:.*:(.*)$/) 
                           metric = metric.rpartition(":").first
                           operation = $1
                         end 
                         datapoints, headers = @diskstore.read("#{metric}:#{retention[0]}:#{DATASTORE_VERSION}", begin_time, end_time)
                         if defined? operation
                           index = headers.index(operation.gsub('upper_', "percentile_")) || 0
                           datapoints = datapoints.collect{|v| {timestamp: v[:timestamp], value: v[:value][index]}}
                           metric = "#{metric}:#{operation}"
                         else
                           {fields: headers, data: datapoints}
                         end
                       else
                         datapoints = @diskstore.read("#{metric}:#{retention[0]}", begin_time, end_time)
                       end

                       break
                     end
                   end
                 end
                 send_data "#{JSON({'interval' => interval, "#{metric}" => datapoints})}\n"
              end
            when command.match(/ping/i)
              send_data "PONG\n"
            when command.match(/quit|exit/i)
              send_data "BYE\n"
              close_connection
            else
              send_data "#{JSON({error: "Unrecognized command #{command}"})}\n"
          end
        rescue Exception => e
          Batsd.logger.info e 
        rescue
          Batsd.logger.warn "Uncaught Error"
        end
      end
    end
    
    # Bind to port+2 and serve up data over TCP. Offers access to
    # both the set of datapoints and the values as JSON arrays.
    class Daemon

      # Create a new daemon and expose options
      def initialize(options={})
        @options = options
        @bind = @options[:bind] || '0.0.0.0'
        @port = @options[:manual_port] || ((@options[:port] || 8125) + 2)
        Batsd::Server.config = @options.merge(port: @port)
      end

      # Run the server
      def run
        Batsd.logger.warn "Starting server on #{@port}"
        EventMachine.threadpool_size = 100
        EventMachine::run do
          EventMachine::start_server(@bind, @port, Batsd::Server)  
        end
      end
    end
  end 
end

