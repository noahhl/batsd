require 'benchmark'
require 'eventmachine'
require 'redis'
require 'aws/s3'

require 'core-ext/array'

require 'batsd/filestore'
require 'batsd/filestore/diskstore'
require 'batsd/filestore/s3'
require 'batsd/redis'
require 'batsd/threadpool'
require 'batsd/receiver'
require 'batsd/server'
require 'batsd/statistics'

require 'batsd/truncator'
require 'batsd/deleter'
require 'batsd/handler'
require 'batsd/handlers/gauge'
require 'batsd/handlers/counter'
require 'batsd/handlers/timer'

# A ruby statsd protocol compatible server. Data is stored to redis and written
# to disk at different levels of aggregation.
module Batsd
  # Current version of the daemon
  VERSION = "0.1.1"
end
