require 'test_helper'
require 'mocha/setup'

class S3Test < Test::Unit::TestCase

  def setup
    Batsd::S3.any_instance.stubs(:establish_connection).returns(true)
    @bucket = 'fake-bucket'

    @s3 = Batsd::S3.new({
      s3: {
        bucket: @bucket
      }
    })

    @statistic = "counters:test_counter:60"
  end

  def teardown
    #FileUtils.rm("test/data/37/2a/372a5d5450ef177a737f6a92c0246436") rescue nil
  end

  def test_store_writes_to_file
    now = Time.now.to_i
    value = "#{now} #{12}"

    @s3.expects(:fetch_file).with('37/2a/372a5d5450ef177a737f6a92c0246436').returns('')
    @s3.expects(:store_file).with('37/2a/372a5d5450ef177a737f6a92c0246436', "#{value}\n")
    @s3.append_value_to_file(@s3.build_filename(@statistic), value)
  end

  def test_read_reads_from_file
    now = Time.now.to_i - 50
    fake_file = ''
    (1..50).each do |i|
      fake_file += "#{now + i} #{i}\n"
    end

    @s3.expects(:fetch_file).with(@s3.build_filename(@statistic)).returns(fake_file).at_least_once

    full_result = @s3.read(@statistic, now.to_s, (now + 50).to_s)
    assert_equal 50, full_result.length
    assert_equal 25, full_result[24][:value].to_f
    partial_result = @s3.read(@statistic, (now+25).to_s, (now + 35).to_s)
    assert_equal 11, partial_result.length
    assert_equal 27, partial_result[2][:value].to_f
  end

  def test_truncate_cleans_up_file
    now = Time.now.to_i - 50
    fake_file = ''
    (1..50).each do |i|
      fake_file += "#{now + i} #{i}\n"
    end

    @s3.expects(:fetch_file).with(@s3.build_filename(@statistic)).returns(fake_file).at_least_once
    @s3.expects(:store_file).with(@s3.build_filename(@statistic), anything).at_least_once

    assert_equal 50, @s3.read(@statistic, now.to_s, (now + 50).to_s).length

    updated_file = @s3.truncate(@s3.build_filename(@statistic), (now+25).to_s)

    @s3.expects(:fetch_file).with(@s3.build_filename(@statistic)).returns(updated_file).at_least_once

    assert_equal 26, @s3.read(@statistic, now.to_s, (now + 50).to_s).length
  end

  def test_delete_unlinks_file
    s3_object = stub
    s3_object.expects(:delete).returns(true)

    AWS::S3::S3Object.expects(:exists?).with(@s3.build_filename(@statistic), @bucket).returns(true)
    AWS::S3::S3Object.expects(:find).with(@s3.build_filename(@statistic), @bucket).returns(s3_object)

    @s3.delete(@s3.build_filename(@statistic))
  end


end
