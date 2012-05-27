# Performance

Performance for Batsd is typically comparable with Graphite performance with similar 
hardware and data volumes. 37signals has been using Batsd with well in excess
of 10,000 incoming observations per second with minimal load on midrange server
hardware with SSDs.

## Ruby version

Ruby 1.9.3 or JRuby 1.6 or later is required.

Batsd makes heavy use of threadpools to defer blocking disk and network operations. 
Because of this, JRuby is the prefered Ruby version to run, preferably on Java
version 1.7 to capture the full performance potential.

For high volumes of data, the maximum heap and stack size for the JVM will
likely need to be raised, eg., by setting `JAVA_OPTS=-Xmx2G -Xms2G -Xmn512m`.
Performance can be improved by deferring garbage collection further with
greater JVM limits.

## Disk

In almost every case, disk performance will be the bottleneck limiting
performance. While you can use consumer HDDs or even a network attached storage
device exposed via NFS, a RAID array of SSDs will offer the best performance.

## Redis

Redis is unlikely to be a performance limitation, though a localhost instance
will offer the best performance. Advice on optimizing Redis further can be
obtained from the [Redis website](http://redis.io).
