module Batsd 
  # 
  # Receives and processes incoming statsd measures via UDP
  #
  # Controls flush timing for each of the handlers.
  #
  module Receiver
    
    # Exposes registered handlers 
    def self.handlers
      @handlers
    end

    # Register an array of handlers
    def self.handlers=(handlers)
      @handlers = handlers
    end
    
    # Startup message after server is launched
    def post_init
      puts "#{Time.now}: batsd receiver is running and knows how to handle " + 
            Batsd::Receiver.handlers.collect{|k, v| k }.join(", ")
    end

    # Receive and handle an incoming UDP message
    #
    # * Split it into the key, value, type, and sample rate (if provided)
    # * Identify the appropriate handler, or log an error if there is no
    #   registered handler for the type of data provided.
    #
    def receive_data(msg)    
      msg.split("\n").each do |row|
        puts "received #{row}" if ENV["VVERBOSE"]
        key, value, type, sample = row.split(/\||:|!/)
        if handler = Batsd::Receiver.handlers[type.strip.to_sym]
          handler.handle(key, value, sample)
        else
          puts "No handler for type #{type}"
        end
      end
    rescue Exception => e
      puts "#{Time.now}: Uncaught error #{e.message}"
    end

    #
    # Interface to run the receiver from the binary
    #
    class Daemon

      # Create a new daemon and set up it's options and 
      # register the handlers provided
      #
      def initialize(handlers, options={})
        @options = options
        @handlers = handlers
        Batsd::Receiver.handlers = handlers
      end

      # Run the event machine server. This will:
      #
      # * Bind to an address and port and process incoming messages
      # * Establish flush timers for each handler that has implemented a
      #   flush method. These timers will happen at the lowest retention 
      #   level (typically 10 seconds)
      #
      def run
        EventMachine::run do
          if RUBY_PLATFORM == "java"
            Thread.current.priority = 10
          end
          bind = @options[:bind] || '0.0.0.0'
          port = @options[:port] || 8125
          puts "#{Time.now}: Starting receiver on batsd://#{bind}:#{port}"
          EventMachine::open_datagram_socket(bind, port, Batsd::Receiver)
          # Have to run the statistics service as part of this process so that
          # it has access to the handler objects, which contain their own
          # statistics
          EventMachine::start_server(bind, port + 1, Batsd::Statistics)

          @handlers.each do |type, handler|
            if handler.respond_to? :flush
              puts "#{Time.now}: Adding flush timer to #{handler}"
              EventMachine.add_periodic_timer(@options[:retentions].keys[0].to_i) do
                EventMachine.defer { handler.flush }
              end
            end
          end

        end
      end

    end

  end 
end
