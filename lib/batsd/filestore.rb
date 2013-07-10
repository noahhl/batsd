module Batsd

  # A wrapper around all file stores (Diskstore and S3), includes commonality and control functions
  class Filestore
    # Creates an instance of the right child depending on configuration
    def self.init(options)
      case Batsd::Server.config[:filestore].downcase
      when 'diskstore' then
        Batsd::Diskstore.new(Batsd::Server.config)
      when 's3' then
        Batsd::S3.new(Batsd::Server.config)
      end
    end

    def build_filename(statistic, root='')
      return unless statistic
      file_hash = Digest::MD5.hexdigest(statistic)
      File.join(@root, file_hash[0,2], file_hash[2,2], file_hash)
    end
  end
end
