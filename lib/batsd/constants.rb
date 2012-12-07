# A ruby statsd protocol compatible server. Data is stored to redis and written
# to disk at different levels of aggregation.
module Batsd
  # Current version of the daemon
  VERSION = "0.1.1"
  DATASTORE_VERSION = 2
  STANDARD_OPERATIONS = ["min", "max", "median", "mean", "stddev", "percentile_90", "percentile_95", "percentile_99"]
end
