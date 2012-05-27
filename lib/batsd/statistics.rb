require 'json'
module Batsd
  # Track and report statistics about the server and all of it's handlers
  module Statistics
    
    # Handle an incoming message on port+1. Valid commands are 'stats', 'exit',
    # and 'quit'.
    # 
    # Statistics are returned over JSON
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
