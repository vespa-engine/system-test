# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "test/unit"
require "test/mocks/resultset_generator"
require "nodetypes/distributor_bucketdb_parser"

class DistrBucketDBParserTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  def test_simple
    status_page = IO.read(File.join(File.dirname(__FILE__), "data", "distr_bucket_db.txt"))
    #puts status_page
    parser = DistributorBucketDBParser.new
    result = parser.parse(status_page)
    assert_equal(3, result.length)
    bucket = result["20000000000000aa"]
    assert_equal(6, bucket.length)
    node = bucket[1]
    assert_equal(8, node.length)
    assert_equal("f120541a", node["crc"])
    assert_equal(2, node["unique_docs"])
    assert_equal(2, node["meta_entries"])
    assert_equal(2, node["unique_docs_size"])
    assert_equal(3, node["utilized_file_size"])
    assert_equal(false, node["trusted"])
    assert_equal(false, node["active"])
    assert_equal(false, node["ready"])
    node = bucket[5]
    assert_equal(8, node.length)
    assert_equal("2a25741a", node["crc"])
    assert_equal(1, node["unique_docs"])
    assert_equal(1, node["meta_entries"])
    assert_equal(1, node["unique_docs_size"])
    assert_equal(1, node["utilized_file_size"])
    assert_equal(true, node["trusted"])
    assert_equal(false, node["active"])
    assert_equal(true, node["ready"])
  end

  class OurMatcher1 < DistributorBucketDBParser::Matcher
  end
  class OurMatcher2 < DistributorBucketDBParser::Matcher
    def initialize(group)
      @group = group
    end

    def countNode(bucket, node)
      return (node / 3 == @group)
    end

    def countProperty(bucket, node, property)
      return (property == "active")
    end

    def countPropertyValue(bucket, node, property, value)
      return value
    end
  end

  def test_count_ready_per_group
    status_page = IO.read(File.join(File.dirname(__FILE__), "data", "distr_bucket_db.txt"))
    parser = DistributorBucketDBParser.new
    result = parser.parse(status_page)
    matcher = OurMatcher1.new
    count = parser.count_instances_matching(result, matcher)
    assert_equal(132, count)
    matcher = OurMatcher2.new(0)
    count = parser.count_instances_matching(result, matcher)
    assert_equal(3, count)
  end

end
