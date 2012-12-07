$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'bundler/setup'
require 'batsd'


@config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + "/../config.yml")).inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
@redis = Batsd::Redis.new(@config)
@diskstore = Batsd::Diskstore.new(@config[:root])
Batsd.logger.level = Logger::DEBUG

