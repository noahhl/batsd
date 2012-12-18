module Batsd
  module Proxy
    class Passthrough < EM::Connection

      def initialize(config)
        @destinations = config["destinations"].collect do |name, spec|
          server(name, spec)
        end
        @deadpool = []
        EM.add_periodic_timer(10) { check_deadpool }
      end
      
      def connected(name)
        puts "#{name} is connected"
      end

      def receive_data(msg)
        @destinations.each do |d|
          d.queue.push msg
        end
      rescue Exception => e
        Batsd.logger.warn "Uncaught error #{e.message} #{e.backtrace.join("\n")}"
      end

      def unbind_backend(name)
        puts "Marking #{name} as dead"
        d = @destinations.find{|d| d.name == name}
        @destinations.delete_if{|d| d.name == name}
        @deadpool.push(d)
      end

      def check_deadpool
        @deadpool.each do |d|
          begin
            @destinations.push server(d.name, d.spec)
            @deadpool.delete_if{|a| a.name == d.name}
          rescue Exception => e
            puts "#{d.name} still dead: #{e}"
          end
        end
      end

      def server(name, spec)
        EventMachine.connect(spec["host"], spec["port"], Batsd::Proxy::Client, EM::Queue.new) do |c|
          c.spec = spec 
          c.name = name 
          c.proxy = self
        end
      end


    end
  end
end

