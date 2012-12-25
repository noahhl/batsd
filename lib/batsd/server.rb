require 'json'
require 'base64'
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

    def serialize(data)
      @marshal ||= Batsd::Server.config[:serializer] == "marshal"
      if @marshal
        Base64.encode64(Marshal.dump(data)).gsub("\n", "")
      else
        JSON(data)
      end
    end
   
    # Set up a redis and diskstore instance per connection
    # so they don't step on each other. Since redis commands
    # are happening in a deferrable, intentionally not using EM-redis
    def post_init
      Batsd.logger.debug "batsd server ready and waiting on #{Batsd::Server.config[:port]} to ship data upon request\n"
      @redis = Batsd::Redis.new(Batsd::Server.config)
      @diskstore = Batsd::Diskstore.new(Batsd::Server.config[:root])
      @retentions = Batsd::Server.config[:retentions]
    end

    def retrieve_datapoints(metric, begin_time, end_time, version)
      version = (version || DATASTORE_VERSION).to_i
      type = metric.partition(":").first
      send :"retrieve_#{type}", metric, begin_time, end_time, version
    end

    def retrieve_gauges(metric, begin_time, end_time, version)
     [@diskstore.read(metric, begin_time, end_time, version), 0]
    end

    def retrieve_counters(metric, begin_time, end_time, version)
      output = nil
      @retentions.each_with_index do |(interval, count), index|
        next unless (interval == @retentions.keys.last) || (Time.now.to_i - (interval * count) < begin_time.to_i)
        if index.zero?
          datapoints = @redis.values_from_zset(metric, begin_time, end_time)
          if version >= 2
             datapoints = datapoints.collect{|v| {timestamp: v[:timestamp], value: v[:value][0]}}
          end
          output = [datapoints, interval]
          break
        else
          datapoints = @diskstore.read("#{metric}:#{interval}", begin_time, end_time, version)
          output = [datapoints, interval]
          break
        end
      end
      output 
    end

    def retrieve_timers(metric, begin_time, end_time, version)
      if metric.match(/^timers:.*:(.*)$/) 
        metric = metric.rpartition(":").first
        operation = $1
      end

      datapoints = headers = []
      output = nil
      @retentions.each_with_index do |(interval, count), index|
        next unless (interval == @retentions.keys.last) || (Time.now.to_i - (interval * count) < begin_time.to_i)
        if index.zero?
          datapoints = @redis.values_from_zset(metric, begin_time, end_time)
          headers = ["count"] + STANDARD_OPERATIONS
        else
          if version >= 2
            datapoints, headers = @diskstore.read("#{metric}:#{interval}:#{DATASTORE_VERSION}", begin_time, end_time, version)
          else
            datapoints = @diskstore.read("#{metric}:#{operation}:#{interval}", begin_time, end_time, version)
          end
        end

        if defined?(operation) && operation && headers && Array(headers).any?
          index = headers.index(operation.gsub('upper_', "percentile_")) || 0
          datapoints = datapoints.collect{|v| {timestamp: v[:timestamp], value: v[:value][index]}}
        elsif headers && Array(headers).any?
          datapoints = {fields: headers, data: datapoints}
        end

        output = [datapoints, interval]
        break
      end
      output
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
              EM.defer { send_data "#{serialize(@redis.datapoints)}\n" }
            when command.match(/values/i)
              EM.defer do
                 command, metric, begin_time, end_time, version = msg_split
                 datapoints, interval = retrieve_datapoints(metric, begin_time, end_time, version)
                 send_data "#{serialize({'interval' => interval, "#{metric}" => datapoints})}\n"
              end
            when command.match(/ping/i)
              send_data "PONG\n"
            when command.match(/quit|exit/i)
              send_data "BYE\n"
              close_connection
            else
              send_data "#{serialize({error: "Unrecognized command #{command}"})}\n"
          end
        rescue Exception => e
          Batsd.logger.info e 
        rescue
          Batsd.logger.warn "Uncaught Error"
        end
      end
    end

    def unbind
      @redis.client.quit
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
        EM.epoll
        EventMachine::run do
          EventMachine::start_server(@bind, @port, Batsd::Server)  
        end
      end
    end
  end 
end

