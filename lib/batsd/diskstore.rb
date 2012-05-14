require 'digest'
require 'fileutils'

module Batsd 
  # Handles disk operations -- writing, truncating, and reading
  class Diskstore
    
    # Create a new diskstore object
    def initialize(root)
      @root = root
    end

    # Calculate the filename that will be used to store the
    # metric to disk.
    #
    # Filenames are MD5 hashes of the statistic name, including any
    # aggregation-based suffix, and are stored in two levels of nested
    # directories (e.g., <code>/00/01/0001s0d03dd0s030d03d</code>)
    #
    def build_filename(statistic)
      return unless statistic
      file_hash = Digest::MD5.hexdigest(statistic)
      File.join(@root, file_hash[0,2], file_hash[2,2], file_hash)
    end

    # Append a value to a file
    #
    # Open the file in append mode (creating directories needed along
    # the way), write the value and a newline, and close the file again.
    #
    def append_value_to_file(filename, value, attempts=0)
      FileUtils.mkdir_p filename.split("/")[0..-2].join("/")
      File.open(filename, 'a+') do |file|
        file.write("#{value}\n")
        file.close
      end
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
      filename = build_filename(statistic)
      begin
        File.open(filename, 'r') do |file| 
          while (line = file.gets)
            ts, value = line.split
            if ts >= start_ts && ts <= end_ts
              datapoints << {timestamp: ts.to_i, value: value}
            end
          end
          file.close
        end
      rescue Errno::ENOENT => e
        puts "Encountered an error trying to read #{filename}: #{e}" if ENV["VVERBOSE"] 
      rescue Exception => e
        puts "Encountered an error trying to read #{filename}: #{e}"
      end
      datapoints
    end

    # Truncates a file by rewriting to a temp file everything after the since
    # timestamp that is provided. The temp file is then renaemed to the
    # original.
    #
    def truncate(filename, since)
      puts "Truncating #{filename} since #{since}" if ENV["VVERBOSE"]
      unless File.exists? "#{filename}tmp"  
        File.open("#{filename}tmp", "w") do |tmpfile|
          File.open(filename, 'r') do |file|
            while (line = file.gets)
              if(line.split[0] >= since rescue true)
                tmpfile.write(line)
              end
            end
            file.close
          end
          tmpfile.close
        end
        FileUtils.cp("#{filename}tmp", filename) rescue nil
      end
    rescue Errno::ENOENT
      puts "Encountered an error trying to truncate #{filename}: #{e}" if ENV["VVERBOSE"] 
    rescue Exception => e
      puts "Encountered an error trying to truncate #{filename}: #{e}"
    ensure 
      FileUtils.rm("#{filename}tmp") rescue nil
    end

  end
end
