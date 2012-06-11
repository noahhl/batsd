# @title Example client
require 'timeout'
require 'json'

# Example client to access data exposed via batsd server
class Client

  attr_accessor :ipaddr, :port, :remote, :timeout, :redis
  
  # Maximum attempts to execute a remote command before giving up
  MAX_ATTEMPTS = 2

  # Create a new client. Optionally, specify a host, port, and timeout in
  # milliseconds
  def initialize(options={})
    self.ipaddr = options[:host] || "127.0.0.1"
    self.port = options[:port] || 8127
    self.timeout = options[:timeout] || 2000
    connect!
  end

  # Get the set of datapoints batsd knows about. Will return an array of
  # strings
  def available
    keys = query_remote("available")
    keys.collect do |k|
      if k.match /^timer/
        ["mean", "min", "max", "upper_90", "stddev", "count"].collect{|a| "#{k}:#{a}"}
      else
        k
      end
    end.flatten
  end


  # Get the values for a given <code>metric_name</code> that's contained in the available
  # set of datapoints within the range of <code>start_timestamp</code> to
  # <code>end_timestamp</code>
  def values(metric_name, start_timestamp, end_timestamp=Time.now, attempt=0)
    results = []
    values = query_remote("values #{metric_name} #{start_timestamp.to_i} #{end_timestamp.to_i}")
    if values[metric_name].nil?
      puts "BatsdClient: #{Thread.current} #{self.remote.addr} Values returned weren't the same as what was asked for (expecting #{metric_name}, got #{values.keys.join(";")})."
      if attempt < MAX_ATTEMPTS
        return values(metric_name, start_timestamp, end_timestamp, attempt+1)
      else
        return []
      end
    end
    results = values[metric_name].collect{|v| { :timestamp => Time.at(v["timestamp"].to_i), :value => v["value"].to_f }  }
    results
  end

  # Clear and reconnect to the remote socket
  def reconnect!
    self.remote = nil
    connect!
  end

  private
    
   # Connect to the remote batsd server over TCP
    def connect!
      Timeout::timeout(5) do
        self.remote = TCPSocket.new(self.ipaddr, self.port) rescue nil
      end
    rescue Timeout::Error => e
      puts "BatsdClient: Couldn't connect to the remote statsd server in the time alloted"
    end

    # Send a command to the remote and attempt to parse the response as JSON
    def query_remote(command, attempt=0)
      Timeout::timeout(self.timeout.to_f / 1000.0) do
        connect! unless self.remote
        self.remote.puts command
        @response = self.remote.gets
        results = JSON.parse(@response)
      end
      rescue TimeoutError => e
        puts "BatsdClient: Timed out on #{command} #{"; retrying." if attempt < MAX_ATTEMPTS}"
        if attempt < MAX_ATTEMPTS 
          query_remote(command, attempt+1)
        else
          []
        end
      rescue Exception => e
        if attempt < MAX_ATTEMPTS 
          query_remote(command, attempt+1)
        else
          puts "BatsdClient: Error querying remote server with #{command} due to #{e}: #{e.message} #{e.backtrace.join("\n")}"
          self.remote = nil
          raise e
        end
    end
  

end
