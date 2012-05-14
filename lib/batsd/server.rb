require 'json'
module Batsd
  # Makes data from statsd available over a TCP socket
  module Server
    def self.config
      @config
    end

    def self.config=(config)
      @config=config
    end
    
    def post_init
      puts "batsd server ready and waiting on #{Batsd::Server.config[:port]} to ship data upon request\n"
      @redis = Batsd::Redis.new(Batsd::Server.config)
      @diskstore = Batsd::Diskstore.new(Batsd::Server.config[:root])
    end

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
        end
      end
    end

    class Daemon

      def initialize(options={})
        @options = options
        @bind = @options[:bind] || '0.0.0.0'
        @port = (@options[:port] || 8125) + 2
        Batsd::Server.config = @options.merge(port: @port)
      end

      def run
        EventMachine.threadpool_size = 100
        EventMachine::run do
          EventMachine::start_server(@bind, @port, Batsd::Server)  
        end
      end
    end
  end 
end

