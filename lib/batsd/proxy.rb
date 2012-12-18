require 'batsd/proxy/daemon'
require 'batsd/proxy/client'
require 'batsd/proxy/passthrough'

module Batsd
  module Proxy

    class << self
      attr_accessor :config
    end

  end
end
