#!/usr/bin/env ruby-local-exec
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../../lib')
require 'rubygems'
require 'bundler/setup'
require 'terminal-table'
require 'batsd'
require 'mocha'

include Batsd::Receiver
config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + "/../../config.yml")).inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
Batsd::Receiver.handlers = { "c" => Batsd::Handler.new(config), 
             "g" => Batsd::Handler.new(config), 
             "ms" => Batsd::Handler.new(config)
           }
Batsd::Handler.any_instance.expects(:handle).returns(true).at_least_once

Batsd.logger.level = Logger::WARN
NUM_ITERATIONS = 10000
print "Starting receiver parser test"
times = []
NUM_ITERATIONS.times do
  type = ["c", "g", "ms"][rand(3)]
  val = rand(1000)
  times << Benchmark.measure do 
    receive_data("test.foo:#{val}|#{type}")
  end.real * 1000000
end

print "\n"

puts Terminal::Table.new(:title => "Receiver parser benchmarks #{NUM_ITERATIONS} iterations (us)",
                         :headings => [ "Min", "Median", "Max", "Mean"],
                         :rows => [[times.min.round(5), times.median.round(5),  times.max.round(5), times.mean.round(5)]])
