# Data types

Batsd is primarily 'wireline' compatible with Etsy's implementation of statsd as detailed in
http://codeascraft.etsy.com/2011/02/15/measure-anything-measure-everything/ and implemented in
https://github.com/etsy/statsd (hereafter called the 'reference' implementation).

Datapoints are always sent over UDP to a server. By convention, the server listens on port 8125.

Datapoints are always formatted as

    keyname:value|datatype

where `keyname` is delimited into sections by dots, value is a numeric value, and datatype is a
string.

The reference implementation generally defines two datatypes:

+ "counters", with a datatype of `c` and an integer value. Counters are aggregated as cumulative
   values over time.
+ "timers", with a datatype of `ms` and an integer value. Gauges are averaged over time.

This implementation supports those datatypes as specified, and further adds:

+ Support for floats as well as integer values for all datatypes
+ "gauges", with a dataype of `g` and a numeric value. Gauges are not aggregated over time.

When stored, datapoints have the type prepended to the keyname using a colon (e.g., `foo:1|c` becomes `counters:foo`)

## Averaging and aggregation

### Gauges

Gauges are not aggregated or averaged in any way - they are stored entirely on disk, and are written as 
soon as they are received (strictly speaking, they are queued to be written as
soon as they are received; actual writing may be delayed slightly).

### Counters

Counters are summed up over the course of each retention interval. No
information about the distribution of values received is retained. 

### Timers

Timers are averaged and several measures are stored about
the distribution:

  * mean               - the mean value of all measurements in that interval
  * min                - the minimum value of all measurements in that interval
  * max                - the maximum value of all measurements in that interval
  * count              - the total number of measurements in that interval
  * upper_90           - the upper 90th percentile threshold that measurements in that interval all fall below
  * standard deviation - the standard deviation of measurements in that interval

These are each calculated and stored for each timer every time an aggregation is performed. They are 
generally treated as separate metrics for all other purposes, with their type (e.g., "mean") appended
to the metric name using a colon delimeter.
