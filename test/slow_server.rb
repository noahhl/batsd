#!/usr/bin/env ruby-local-exec
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'bundler/setup'
require 'eventmachine'

module Slowboy
  def receive_data(msg)
    puts msg if ENV["VERBOSE"]
    sleep (ENV["SLOWBOY"] || 0).to_f
  end
end

EventMachine::run do
  EventMachine::start_server('0.0.0.0', ARGV[0].to_i, Slowboy)  
end
