module Batsd
  module Proxy

    class Client < EM::Connection
      attr_accessor :proxy, :name, :spec
      attr_reader :queue

      def initialize(q)
        @queue = q
        cb = Proc.new do |msg|
          begin
            send_data(msg)
            @queue.pop &cb
          rescue Exception => e
            Batsd.logger.warn "Can't send data, discarding"
          end
        end
        q.pop &cb
      end

      def connection_completed
        @proxy.connected(@name)
      end


      # Notify upstream proxy that the backend server is done
      # processing the request
      def unbind
        @proxy.unbind_backend(@name)
      end


    end

  end
end
