module Batsd
  module Proxy
    class Daemon 

      def initialize(config)
        Batsd::Proxy.config = @config = config
        @handler = case @config[:proxy]["strategy"]
                  when "passthrough" then Batsd::Proxy::Passthrough
                  end

      end

      def run
        EventMachine.threadpool_size = 100
        EventMachine.epoll

        bind = @config[:bind] || '0.0.0.0'
        port = @config[:manual_port] || ((@config[:port] || 8125) )
        EventMachine::run do
          Batsd.logger.warn "Starting proxy on batsd://#{bind}:#{port}"
          EventMachine::open_datagram_socket(bind, port, @handler, @config[:proxy] )
          EventMachine::start_server(bind, port, @handler, @config[:proxy])  
        end
      end

    end
  end
end
