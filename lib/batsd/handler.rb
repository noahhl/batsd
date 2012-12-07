module Batsd
  # 
  # Abstract interface for handling different types of data
  # (e.g., counters, timers, etc.). 
  #
  # Generally, this should be subclassed to provide the specific 
  # functionality desired. If left unmodified, it provides an echo
  # handler when run with <code>ENV["VVERBOSE"]</code>, and is silent otherwise.
  #
  class Handler
   
    # Creates a new handler object and spawns a threadpool. If
    # <code>options[:threadpool_size]</code> is specified, that will be used
    # (default 100 threads)
    #
    def initialize(options={})
      @threadpool = Threadpool.new(options[:threadpool_size] || 100)
      @fast_threadpool = Threadpool.new((options[:threadpool_size] || 100) / 10)
      @statistics = {}
    end
  
    # Handle the key, value, and sample rate specified in the
    # key. Override this in individual handlers to actually 
    # do something useful
    #
    def handle(key, value, sample_rate)
      @threadpool.queue do
        Batsd.logger.debug "Received #{key} #{value} #{sample_rate}" 
      end
    end

    # Exposes the threadpool used by the handler
    #
    def threadpool
      @threadpool
    end

    # Provide some basic statistics about the handler. The preferred
    # way to augment these is to modify the <code>@statistics</code> 
    # object from subclassed handlers
    #
    def statistics
      {
        threadpool_size: @threadpool.pool + @fast_threadpool.size,  
        queue_depth: @threadpool.size + @fast_threadpool.size
      }.merge(@statistics)
    end

  end
end
