require 'benchmark'
require 'eventmachine'
require 'redis'

require 'core-ext/array'

require 'batsd/diskstore'
require 'batsd/redis'
require 'batsd/threadpool'
require 'batsd/receiver'
require 'batsd/truncator'
require 'batsd/handler'
require 'batsd/handlers/gauge'
require 'batsd/handlers/counter'

# A ruby statsd protocol compatible server. Data is stored to redis and written
# to disk at different levels of aggregation.
module Batsd
end
