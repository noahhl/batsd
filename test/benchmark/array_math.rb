#!/usr/bin/env ruby-local-exec
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../../lib')
require 'rubygems'
require 'bundler/setup'
require 'terminal-table'
require 'core-ext/array'
require 'batsd/constants'
require 'benchmark'


def generate_random_array(size=10000)
  size.times.collect{|d| rand * 100.0}
end

puts "Starting array math benchmark...\n"

NUM_ITERATIONS = 100
 rows = []
Batsd::STANDARD_OPERATIONS.each do |op|
  times = []
  print '.'
  NUM_ITERATIONS.times do 
    array = generate_random_array
    times << Benchmark.measure do 
      array.send(op)
    end.real * 1000
  end
  rows << [op, times.min.round(2), times.median.round(2), times.max.round(2), times.mean.round(2)]
end
print "\n"

puts Terminal::Table.new(:title => "Array benchmarks for #{NUM_ITERATIONS} iterations (ms)",
                         :headings => ["Operation", "Min", "Median", "Max", "Mean"],
                         :rows => rows)

