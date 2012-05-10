require 'json'
module Batsd
  module Statistics
    
    def post_init
      puts "batsd statistics are available"
    end

    def receive_data(msg)
      if msg.match /stats/
        stats = {}
        Batsd::Receiver.handlers.each{|type, handler| stats[type] =  handler.statistics }
        send_data "#{stats.to_json}\n"
      elsif msg.match /quit|exit/
        send_data "BYE\n"
        close_connection
      end
    end

  end
end
