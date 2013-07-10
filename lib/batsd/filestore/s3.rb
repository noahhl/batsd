module Batsd
  # Handles writing, truncating, and reading on AWS S3 buckets
  # Meant to be a replacement for Batsd::Diskstore for usage on heroku
  class S3 < Filestore
    S3_FOLDER_EXT = '_$folder$'

    def initialize(options)
      @credentials = options[:s3]
      @bucket      = options[:s3][:bucket]
    end

    # Fetch a file from AWS S3
    def fetch_file(filename)
      establish_connection
      data = AWS::S3::S3Object.value(filename, @bucket) if AWS::S3::S3Object.exists?(filename, @bucket) 

      data || ''
    end


    # Store a file to AWS S3
    # folders and file types are handled by the gem

    def store_file(filename, file_data)
      establish_connection

      AWS::S3::S3Object.store filename, StringIO.new(file_data), @bucket, access: :authenticated_read
    end

    # Append a value to a file
    #
    # Open the file in append mode (creating directories needed along
    # the way), write the value and a newline, and close the file again.
    #
    def append_value_to_file(filename, value, attempts=0)
      file_data  = fetch_file(filename) + "#{value}\n"

      store_file filename, file_data
    rescue Exception => e
      puts "Encountered an error trying to store to #{filename}: #{e} #{e.message} #{e.backtrace if ENV["VERBOSE"]}"
      if attempts < 2
        puts "Retrying #{filename} for the #{attempts+1} time"
        append_value_to_file(filename, value, attempts+1)
      end
    end

    # Reads the set of values in the range desired from file
    #
    # Reads until it reaches end_ts or the end fo the file. Returns an array
    # of <code>{timestamp: ts, value: v}</code> hashes.
    #
    def read(statistic, start_ts, end_ts)
      datapoints = []
      filename = build_filename statistic

      begin
        file_data = fetch_file(filename)
        file_data.split("\n").each do |line|
          ts, value = line.split
          if ts >= start_ts && ts <= end_ts
            datapoints << { timestamp: ts.to_i, value: value }
          end
        end
      rescue Exception => e
        puts "Encountered an error trying to read #{filename}: #{e} #{e.message} #{e.backtrace if ENV["VERBOSE"]}"
      end

      datapoints
    end

    # Truncates a file by rewriting to a temp file everything after the since
    # timestamp that is provided. The temp file is then renaemed to the
    # original.
    #
    def truncate(filename, since)
      puts "Truncating #{filename} since #{since}" if ENV["VVERBOSE"]

      truncated_file_data = ''
      old_file_data       = fetch_file(filename)

      old_file_data.split("\n").each do |line|
        truncated_file_data += "#{line}\n" if(line.split[0] >= since rescue true)
      end

      store_file filename, truncated_file_data

      truncated_file_data
    rescue Exception => e
      puts "Encountered an error trying to truncate #{filename}: #{e} #{e.message} #{e.backtrace if ENV["VERBOSE"]}"
    end

    # Deletes a file, if it exists.
    # If :delete_empty_dirs is true, empty directories will be deleted too.
    # TODO: Support for :delete_empty_dirs
    #
    def delete(filename, options={})
      establish_connection

      AWS::S3::S3Object.find(filename, @bucket).delete if AWS::S3::S3Object.exists? filename, @bucket
    rescue Exception => e
      puts "Encountered an error trying to delete #{filename}: #{e} #{e.message} #{e.backtrace if ENV["VERBOSE"]}"
    end

    def establish_connection
      unless AWS::S3::Base.connected?
        AWS::S3::Base.establish_connection! access_key_id: @credentials[:access_key], secret_access_key: @credentials[:secret_access_key]
      end
    end
  end
end
