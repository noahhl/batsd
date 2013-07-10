module Batsd

  # A wrapper around all file stores (Diskstore and S3), includes commonality and control functions
  class Filestore
    attr_accessor :root

    # Creates an instance of the right child depending on configuration
    def self.init(options)

      unless options[:filestore]
        Batsd::Diskstore.new diskstore: { root: (options[:root] || options[:diskstore][:root]) }
      else
        case options[:filestore].downcase
        when 'diskstore' then
          Batsd::Diskstore.new(options)
        when 's3' then
          Batsd::S3.new(options)
        end
      end
    end

    def build_filename(statistic)
      return unless statistic
      paths     = []
      file_hash = Digest::MD5.hexdigest(statistic)

      paths << @root if @root
      paths << file_hash[0,2]
      paths << file_hash[2,2]
      paths << file_hash

      File.join(paths)
    end
  end
end
