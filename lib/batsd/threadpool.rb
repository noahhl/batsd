require 'thread'
# A basic implementation of a FIFO worker threadpool
class Threadpool

  # Create a new threadpool, complete with queue and
  # a spun up pool of <code>size</code> workers. Workers
  # will be active immediately
  #
  def initialize(size)
    @queue = Queue.new
    @pool = []
    size.times do |i|
      @pool << Thread.new do
        loop do
          job, args = @queue.pop
          job.call(*args)
        end
      end
    end
  end

  # Add a new procedure to the queue
  # 
  # Example:
  #
  #    @threadpool.queue arg1, arg2 do |x, y|
  #       puts x # will be equal to arg1
  #       puts y # will be equal to arg2
  #    end
  #
  def queue(*args, &block)
    @queue << [block, args]
  end

  # Returns the size of the queue of outstanding jobs
  #
  def size
    @queue.size
  end

  # Returns the size of the pool of workers
  #
  def pool 
    @pool.size
  end

end
