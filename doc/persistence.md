# Persistence

## Historical context

Etsy's original ("reference") implementation of statsd primarily served as a first level aggregation
and passthrough of data to Graphite (http://graphite.wikidot.com) and its associated Whisper storage
engine. In this case, it performs the first aggregation over the course of its flush interval
(typically 10 seconds in operation) and then passes those aggregated values to Graphite to store.
It does not directly provide a persistence model.

Batsd uses two datastores to store historical data.

+ Redis is used to store recent, near realtime data. In most cases,
  this will be used for every-10-second data for the last 1-24 hours.
+ Longer history, aggregated data is stored in "flat" files on disk. This could be anywhere from a
  one week retention to a 5 year retention

##Configuration

The configuration of retention levels is similar in concept to Graphite, and is specified in the config
file:

    retentions:
      10:  360 # store data at 10 second increments for 1 hour
      60:  10080  # store data at 1 minute increments for 1 week
      600: 52594 # store data at 10 minute increments for 1 year

The shortest-term aggregation is always stored in Redis; the latter ones always stored to disk. In
the future, this may be configurable.

##Redis persistency

Near term data stored in redis is stored in sorted sets, one per datapoint, with the Unix timestamp
as the score and a string structured as `#{now}<X>#{value}` as the value. This
does mean that the string "<X>" is a reserved component in Batsd, and cannot be
used in any key names.

In addition to storing that sorted set, the current set of timer values is
stored as a single string with expiry set to be used for later aggregations.

A cleanup process is run occasionally to truncate the sorted sets using a `ZREMRANGEBYSCORE`. 
See [hisotrical truncation](index.html#Historical_truncation) for details on
configuring this.

##Diskstore

Longer duration data is stored in flat files located within subdirectories of the `root` specified
in the configuration file.

The location of a file will be determined by the MD5 hash of `#{metric_name}:#{aggregationLevel}`.
Files are then stored two subdirectories deep using the first four characters of that hash.

For example, with a `root` of `/statsd`, the path for the 60 second aggregation of `test_metric`
will be `/statsd/88/b4/88b4ca597dfc2d67438cc26140b2615b`.

Data is written to these files in `#{timestamp} #{value}` format, with each measurement separated by a `\n`
newline character, in sequential order.
