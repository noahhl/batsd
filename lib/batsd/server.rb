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
      puts "batsd server ready and waiting on #{Batsd::Server.config[:port]} to ship data upon request\n"
      @redis = Batsd::Redis.new(Batsd::Server.config)
      @diskstore = Batsd::Diskstore.new(Batsd::Server.config[:root])
    end
    
    # Handle a command received over the server port and return
    # the datapoints, values, or a PONG as requested.
    def receive_data(msg)  
      msg.split("\n").each do |row|
        begin
          command = row.split(" ")[0]
          return unless command 
          case
            when command.match(/available/i)
              EM.defer { send_data "#{JSON(@redis.datapoints)}\n" }
            when command.match(/values/i)
              EM.defer do
                 command, metric, begin_time, end_time = row.split(" ")
                 datapoints = []
                 if metric.match(/^gauge/)
                   datapoints = @diskstore.read(metric, begin_time, end_time)
                 else
                   Batsd::Server.config[:retentions].each_with_index do |retention, index|
                     next if (Time.now.to_i - (retention[0] * retention[1]) > begin_time.to_i)
                     if index.zero?
                       datapoints = @redis.values_from_zset(metric, begin_time, end_time)
                       break
                     else
                       datapoints = @diskstore.read("#{metric}:#{retention[0]}", begin_time, end_time)
                       break
                     end
                   end
                 end
                 send_data "#{JSON({"#{metric}" => datapoints})}\n"
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
          puts e if ENV["VERBOSE"]
        rescue
          puts "Uncaught Error"
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
        @port = (@options[:port] || 8125) + 2
        Batsd::Server.config = @options.merge(port: @port)
      end

      # Run the server
      def run
        EventMachine.threadpool_size = 100
        EventMachine::run do
          EventMachine::start_server(@bind, @port, Batsd::Server)  
        end
      end
    end
  end 
end

