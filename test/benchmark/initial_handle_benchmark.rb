#!/usr/bin/env ruby-local-exec
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../../lib')
load File.dirname(__FILE__) + '/../../config/boot.rb'
require 'terminal-table'

include Batsd::Receiver
@config[:root] = File.dirname(__FILE__) + "/../../tmp/test_data"
Batsd::Receiver.handlers = { c: Batsd::Handler::Counter.new(@config), 
                 g: Batsd::Handler::Gauge.new(@config), 
                 ms: Batsd::Handler::Timer.new(@config)
               }


Batsd.logger.level = Logger::ERROR
NUM_ITERATIONS = 100
print "Starting initial receiver handle test"
rows = []
["c", "g", "ms"].each do |type|
  times = []
  NUM_ITERATIONS.times do
    FileUtils.rm_rf(@config[:root])
    FileUtils.mkdir_p(@config[:root])
    sleep 0.002
    val = rand(1000)
    times << Benchmark.measure do 
      receive_data("test.foo:#{val}|#{type}")
    end.real * 1000
  end
  rows << [type, times.min.round(2), times.median.round(2), times.max.round(2), times.mean.round(2)]
end

print "\n"

puts Terminal::Table.new(:title => "Initial handle benchmarks for #{NUM_ITERATIONS} iterations (ms)",
                         :headings => ["Datatype", "Min", "Median", "Max", "Mean"],
                         :rows => rows)
