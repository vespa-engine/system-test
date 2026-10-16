# Copyright Vespa.ai. All rights reserved.

require 'test/unit'
require 'feature_flags_file'
require 'json'

class FeatureFlagsFileTest < Test::Unit::TestCase

  def setup
    @fake_vespa_home = 'testdata_feature_flags'
    @testfile = "#{@fake_vespa_home}/var/vespa/flag.db"
    FileUtils.mkdir_p(File.dirname(@testfile))
    @file = FeatureFlagsFile.new(@fake_vespa_home)
  end

  def teardown
    FileUtils.rm_rf(@fake_vespa_home)
  end

  def active_json
    JSON.parse(File.read(@testfile))
  end

  def backup_json
    JSON.parse(File.read("#{@testfile}.orig"))
  end

  def test_backup_and_restore
    @file.backup(false)
    assert_equal({'flags' => []}, active_json)
    assert_equal({'flags' => []}, backup_json)
    @file.set('id00', 'rules00')
    assert_equal({'flags' => [{'id' => 'id00', 'rules' => 'rules00'}]}, active_json)
    assert_equal({'flags' => []}, backup_json)
    @file.backup(false)
    assert_equal({'flags' => []}, backup_json)
    @file.backup(true)
    assert_equal({'flags' => [{'id' => 'id00', 'rules' => 'rules00'}]}, backup_json)
    @file.set('id01', 'rules01')
    assert_equal({'flags' => [{'id' => 'id00', 'rules' => 'rules00'}, {'id' => 'id01', 'rules' => 'rules01'}]}, active_json)
    @file.restore
    assert_equal({'flags' => [{'id' => 'id00', 'rules' => 'rules00'}]}, active_json)
  end

  def test_set
    @file.set('id00', 'rules00')
    @file.set('id01', 'rules01')
    @file.set('id02', 'rules02')
    @file.set('id01', 'rules01b')
    assert_equal({'flags' => [{'id' => 'id00', 'rules' => 'rules00'}, {'id' => 'id02', 'rules' => 'rules02'}, {'id' => 'id01', 'rules' => 'rules01b'}]}, active_json)
    @file.set('id02', nil)
    assert_equal({'flags' => [{'id' => 'id00', 'rules' => 'rules00'}, {'id' => 'id01', 'rules' => 'rules01b'}]}, active_json)
  end

end
