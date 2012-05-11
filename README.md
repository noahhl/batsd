Batsd 
======

Batsd is a ruby-based daemon for aggregating and storing statistics. It targets
"wireline" compatibility with Etsy's StatsD implementation.

Batsd requires Ruby 1.9.2 or JRuby 1.6 or greater.

### Installation

    git clone git://github.com/noahhl/batsd
    cd batsd
    bundle install
    bundle exec bin/batsd

### Configuration

Edit config.yml to your liking. Data at the first retention level is stored
in redis; further data retentions are stored on disk

Example config.yml

    bind: 0.0.0.0
    port: 8125
    root: tmp/statsd # Root path to store disk aggregations
    redis:
      host: 127.0.0.1
      port: 6379
    retentions:
      10:  360 # store data at 10 second increments for 1 hour
      60:  10080  # store data at 1 minute increments for 1 week
      600: 52594 # store data at 10 minute increments for 1 year

Batsd will actually use three consecutive ports:
  * The port you specified will be the "receiver" port, which listens for incoming measurements over UDP.
  * One port higher will expose a statistics interface over TCP
  * Two ports higher will be used by the server to expose data to clients

### Usage 
Run the receiver ("receiver" argument is optional):

    batsd -c config.yml receiver

Run the server to expose data to clients
    
    batsd -c config.yml server

Truncate historical aggregations:
    
    batsd -c config.yml truncate 10 # Truncates zsets for 10 second aggregation
    batsd -c config.yml truncate 60 # Truncates files from disk for 60 second aggregation

Print statistics:

    batsd -c config.yml stats

