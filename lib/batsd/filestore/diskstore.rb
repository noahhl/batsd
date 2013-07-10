require 'fileutils'
module Batsd 
  # Handles disk operations -- writing, truncating, and reading
  class Diskstore < Filestore
    
    # Create a new diskstore object
    def initialize(options)
      @root = options[:diskstore][:root]
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
    rescue Errno::ENOENT => e
      puts "Encountered an ENOENT error trying to truncate #{filename}: #{e}" if ENV["VVERBOSE"] 
    rescue Exception => e
      puts "Encountered an error trying to truncate #{filename}: #{e.class}"
    ensure 
      FileUtils.rm("#{filename}tmp") rescue nil
    end

    # Deletes a file, if it exists.
    # If :delete_empty_dirs is true, empty directories will be deleted too.
    #
    def delete(filename, options={})
      if File.exists? filename
        FileUtils.rm(filename)
      end

      if options[:delete_empty_dirs]
        p = filename
        begin
          2.times do
            p = File.dirname(p)
            begin
              Dir.rmdir(p) 
            rescue Errno::ENOTEMPTY # only delete if dir is empty, else break
              puts "#{p} is not empty, skipping" if ENV["VERBOSE"]
              break 
            end
          end
        rescue => e
          puts "Encountered an error trying to remove empty directory #{p}: #{e.class}"
        end
      end
    rescue Errno::ENOENT => e
      puts "Encountered an ENOENT error trying to delete #{filename}: #{e}" if ENV["VVERBOSE"] 
    rescue Exception => e
      puts "Encountered an error trying to delete #{filename}: #{e.class}"
    end
  end
end
