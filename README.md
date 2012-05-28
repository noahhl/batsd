Batsd 
======

Batsd is a ruby-based daemon for aggregating and storing statistics. It targets
"wireline" compatibility with Etsy's StatsD implementation.

Batsd differs from etsy's statsd implementation primarily in how it stores data
-- data is stored to a combination of Redis and flat files on disk. You can
read more about persistence in [About:
Persistence](http://noahhl.github.com/batsd/doc/file.persistence.html).

Batsd grew out of usage at [37signals](http://37signals.com), where it has been
used in some form for the last year, recording upwards of one gigabyte worth of
metrics per day. An [earlier form](https://github.com/noahhl/statsd-server) was
inspired by [quasor](https://github.com/quasor/statsd). 

### Documentation:

  * [Getting started](http://noahhl.github.com/batsd/doc/index.html#Getting_started)
  * [Getting help](http://noahhl.github.com/batsd/doc/index.html#Getting_help_and_contributing)
  * [About: Datatypes](http://noahhl.github.com/batsd/doc/file.datatypes.html)
  * [About: Persistence](http://noahhl.github.com/batsd/doc/file.persistence.html)
  * [About: Performance](http://noahhl.github.com/batsd/doc/file.performance.html)
  * [Annotated source code](http://noahhl.github.com/batsd/doc/main.html)
  * [Future plans](http://noahhl.github.com/batsd/doc/file.future.html)
  * [License](http://noahhl.github.com/batsd/doc/index.html#License)


# Getting started
### Installation
#### Pre-requisites
Batsd requires Ruby 1.9.2 or JRuby 1.6 or greater, and access to a Redis
v2.6.0-rc3 or later instance.


    git clone git://github.com/noahhl/batsd && cd batsd && bundle install

### Configuration

Edit config.yml to your liking. 

Example config.yml

    # Host and port to bind to for stats collection
    bind: 0.0.0.0
    port: 8125
    # Where to store data. Data at the first retention level is stored
    # in redis; further data retentions are stored on disk
    
    # Root path to store disk aggregations
    root: /statsd 
    redis:
      host: 127.0.0.1
      port: 6379
    
    # Configure how much data to retain at what intervals
    # Key is seconds, value is number of measurements at that
    # aggregation to retain
    retentions:
      10:  360 # store data at 10 second increments for 1 hour
      60:  10080  # store data at 1 minute increments for 1 week
      600: 52594 # store data at 10 minute increments for 1 year

    # Automatically truncate datasets from within the receiver process
    autotruncate: false

#### Port usage
Batsd will actually use three consecutive ports:

  * The port you specified will be the "receiver" port, which listens for 
    incoming measurements over UDP. By convention, port 8125 is typically used for this.
  * One port higher will expose a statistics interface over TCP to monitor the
    health and performance of the daemon.
  * Two ports higher will be used by the server to expose data to clients over
    TCP.

#### Historical truncation
Batsd must occasionally truncate the data that is stored in Redis and on disk
to prevent it from growing more than desired.

There are two options for doing this:

  1) Setting up truncate commands to be run via crontab or some other
  scheduler. The recommended interval is 0.5-2x the duration retained for
  a given interval (e.g., 30-120 minutes if storing one hour of 10 second
  data). *This is the recommended approach to truncating.*

  Truncations can be run using the `bin/batsd -c path/to/config.yml  truncate
  #{interval}` syntax.
  
  An example configuration crontab:

      # truncate 10 second aggregations
      0 * * * * bash -l -c 'cd /u/apps/batsd/current && ./bin/batsd -c /u/apps/batsd/current/config.yml truncate 10'
      # truncate 60 second aggregations
      0 0 * * 2,5 bash -l -c 'cd /u/apps/batsd/current && ./bin/batsd -c /u/apps/batsd/current/config.yml truncate 60'

  2) *Not recommended*: you can enable autotruncation, which will automatically
  truncate at 1x the retained duration by running a new thread within the
  receiver daemon. This is not recommended, because it will always be relative
  to the start time of the daemon; this makes it easy to miss truncations.

### Usage 
Run the receiver ("receiver" argument is optional):

    batsd -c config.yml receiver

Run the server to expose data to clients
    
    batsd -c config.yml server

The server is run as a separate process to allow for controlled upgrades of one
or the other component, without affecting data acquisition or presentation.

Example scripts to send data to statsd from various sources are included in
`examples/acquisition/`. A sample client to extract data is included in
`examples/client.rb`.
[jeremy/statsd](https://github.com/jeremy/statsd-ruby.git) is the recommended
ruby statsd client, regardless of whether using batsd or another server
implementation.

# Getting help and contributing

### Getting help with Batsd
The fastest way to get help is to send an email to batsd@librelist.com. 
Github issues and pull requests are checked regularly, but email is always the fastest way to get help.

### Contributing
Pull requests with passing tests are welcomed and appreciated.

# License

 Copyright (c) 2012 

 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
