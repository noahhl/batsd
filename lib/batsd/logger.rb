require 'logger'

module Batsd
  
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @logger
  end

end
