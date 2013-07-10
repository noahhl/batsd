require 'test_helper'
class FilestoreTest < Test::Unit::TestCase

  def setup
    @filestore = Batsd::Filestore.new()
    @statistic = "counters:test_counter:60"
  end

  def test_filename_calculation_with_root
    @filestore.root = 'test/data'
    assert_equal "test/data/37/2a/372a5d5450ef177a737f6a92c0246436", @filestore.build_filename(@statistic)
  end

  def test_filename_calculation_without_root # happens with S3
    @filestore.root = nil
    assert_equal "37/2a/372a5d5450ef177a737f6a92c0246436", @filestore.build_filename(@statistic)
  end

  def test_init_diskstore
    options = {
      filestore: 'diskstore',
      diskstore: {
        root: 'test/data'
      }
    }

    assert_equal Batsd::Filestore.init(options).class, Batsd::Diskstore
  end

  def test_init_s3
    options = {
      filestore: 's3',
      s3: {
        bucket: 'bucket'
      }
    }

    assert_equal Batsd::Filestore.init(options).class, Batsd::S3
  end
end
