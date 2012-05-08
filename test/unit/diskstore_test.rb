require 'test_helper'
class DiskstoreTest < Test::Unit::TestCase

  def setup
    @diskstore = Batsd::Diskstore.new("test/data")
    @statistic = "counters:test_counter:60"
  end
  
  def teardown
    FileUtils.rm("test/data/37/2a/372a5d5450ef177a737f6a92c0246436") rescue nil
  end

  def test_filename_calculation
    assert_equal "test/data/37/2a/372a5d5450ef177a737f6a92c0246436", @diskstore.build_filename(@statistic)
  end

  def test_store_writes_to_file
    now = Time.now.to_i
    value = "#{now} #{12}"
    assert !File.exists?("test/data/37/2a/372a5d5450ef177a737f6a92c0246436")
    @diskstore.append_value_to_file(@diskstore.build_filename(@statistic), value)
    assert_equal "#{value}\n", File.read(File.open("test/data/37/2a/372a5d5450ef177a737f6a92c0246436"))
  end

  def test_read_reads_from_file
    now = Time.now.to_i - 50
    (1..50).each do |i|
      @diskstore.append_value_to_file(@diskstore.build_filename(@statistic), "#{now + i} #{i}")
    end
    full_result = @diskstore.read(@statistic, now.to_s, (now + 50).to_s)
    assert_equal 50, full_result.length
    assert_equal 25, full_result[24][:value].to_f
    partial_result = @diskstore.read(@statistic, (now+25).to_s, (now + 35).to_s)
    assert_equal 11, partial_result.length
    assert_equal 27, partial_result[2][:value].to_f
  end

  def test_truncate_cleans_up_file
    now = Time.now.to_i - 50
    (1..50).each do |i|
      @diskstore.append_value_to_file(@diskstore.build_filename(@statistic), "#{now + i} #{i}")
    end
    assert_equal 50, @diskstore.read(@statistic, now.to_s, (now + 50).to_s).length
    @diskstore.truncate(@diskstore.build_filename(@statistic), (now+25).to_s)
    assert_equal 26, @diskstore.read(@statistic, now.to_s, (now + 50).to_s).length
  end


end
