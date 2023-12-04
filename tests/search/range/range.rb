# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class RangeSearch < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
    set_description("Test range search")
  end

  def self.final_test_methods
    ['test_range',
     'test_range_with_hash_dictionary',
     'test_range_with_btree_and_hash_dictionary',
     'test_range_with_no_dictionary',
     'test_range_streaming']
  end

  def test_range
    @params = { :search_type => "ELASTIC" }
    deploy_app(SearchApp.new.
               cluster_name("test").
               sd(selfdir+"test.sd"))
    start_feed_and_check(true)
  end

  def test_range_with_hash_dictionary
    @params = { :search_type => "ELASTIC" }
    deploy_app(SearchApp.new.
               cluster_name("test").
               sd(selfdir+"hash_dictionary/test.sd"))
    start_feed_and_check(false)
  end

  def test_range_with_btree_and_hash_dictionary
    @params = { :search_type => "ELASTIC" }
    deploy_app(SearchApp.new.
               cluster_name("test").
               sd(selfdir+"btree_and_hash_dictionary/test.sd"))
    start_feed_and_check(true)
  end

  def test_range_with_no_dictionary
    @params = { :search_type => "ELASTIC" }
    deploy_app(SearchApp.new.
               cluster_name("test").
               sd(selfdir+"no_dictionary/test.sd"))
    start_feed_and_check(false)
  end

  def test_range_streaming
    @params = { :search_type => "STREAMING" }
    deploy_app(SearchApp.new.
               cluster_name("test").
               sd(selfdir+"streaming/test.sd"))
    start_feed_and_check(false)
  end

  def start_feed_and_check(support_range_limit)
    start
    feed_docs
    check_ranges("i1", support_range_limit)
    check_ranges("f1", support_range_limit)
    check_ranges("m1", support_range_limit)
    check_ranges("w1", support_range_limit)
    check_ranges("w2", support_range_limit)
    check_range_optimizations
  end

  def feed_docs
    feed(:file => selfdir + "docs.xml", :timeout => 240)
    wait_for_hitcount('query=sddocname:test&type=all', 5)
  end

  def check_ranges(field, support_range_limit)
    check_point_lookups(field)
    check_normal_ranges(field)
    check_limited_ranges(field, support_range_limit)
  end

  def check_point_lookups(field)
    check_yql(field, "1", 2)
    check_yql(field, "2", 1)
    check_yql(field, "3", 2)
  end

  def check_normal_ranges(field)
    check_normal_ranges_standard(field)
    check_normal_ranges_yql(field)
    check_normal_ranges_not_quite_yql(field)
  end

  def check_yql(field, term, hits)
    assert_hitcount("yql=select %2a from sources %2a where " + field + " contains \"" + term + "\"", hits)
  end

  def assert_yql_hitcount(query, hits)
    encoded_form=URI.encode_www_form([['yql', "select * from sources * where #{query}"]])
    assert_hitcount(encoded_form, hits)
  end

  def check_normal_ranges_yql(field)
    assert_yql_hitcount("range(#{field}, 1, 2)", 3)
    assert_yql_hitcount("range(#{field}, 1, 4)", 5)
    assert_yql_hitcount("range(#{field}, 1, 3)", 5)
    assert_yql_hitcount("({bounds:\"rightOpen\"}range(#{field}, 1, 3))", 3)
    assert_yql_hitcount("({bounds:\"leftOpen\"}range(#{field}, 1, 2))", 1)
    assert_yql_hitcount("({bounds:\"open\"}range(#{field}, 1, 3))", 1)
    assert_yql_hitcount("({bounds:\"open\"}range(#{field}, 1, 2))", 0)
    assert_yql_hitcount("range(#{field}, 1, Infinity)", 5)
    assert_yql_hitcount("({bounds:\"rightOpen\"}range(#{field}, 1, Infinity))", 5)
    assert_yql_hitcount("range(#{field}, -Infinity, 4)", 5)
    assert_yql_hitcount("({bounds:\"leftOpen\"}range(#{field}, -Infinity, 4))", 5)
    assert_yql_hitcount("range(#{field}, -Infinity, Infinity)", 5)
    assert_yql_hitcount("({bounds:\"open\"}range(#{field}, -Infinity, Infinity))", 5)
    assert_yql_hitcount("range(#{field}, 1.0, 1.7976931348623157E308)", 5)
    assert_yql_hitcount("1 = #{field}", 2)
    assert_yql_hitcount("2 = #{field}", 1)
    assert_yql_hitcount("3 = #{field}", 2)
    assert_yql_hitcount("1 <= #{field}", 5)
    assert_yql_hitcount("2 <= #{field}", 3)
    assert_yql_hitcount("3 <= #{field}", 2)
    assert_yql_hitcount("4 <= #{field}", 0)
    assert_yql_hitcount("0 < #{field}", 5)
    assert_yql_hitcount("1 < #{field}", 3)
    assert_yql_hitcount("2 < #{field}", 2)
    assert_yql_hitcount("3 < #{field}", 0)
    assert_yql_hitcount("4 > #{field}", 5)
    assert_yql_hitcount("3 > #{field}", 3)
    assert_yql_hitcount("2 > #{field}", 2)
    assert_yql_hitcount("1 > #{field}", 0)
    assert_yql_hitcount("3 >= #{field}", 5)
    assert_yql_hitcount("2 >= #{field}", 3)
    assert_yql_hitcount("1 >= #{field}", 2)
    assert_yql_hitcount("0 >= #{field}", 0)
  end

  def check_normal_ranges_not_quite_yql(field)
    check_yql(field, "[1%3b2]", 3)
    check_yql(field, "[1%3b2]", 3)
    check_yql(field, "[1%3b4]", 5)
    check_yql(field, "[1%3b3]", 5)
    check_yql(field, "[1%3b3>", 3)
    check_yql(field, "<1%3b2]", 1)
    check_yql(field, "<1%3b3>", 1)
    check_yql(field, "<1%3b2>", 0)

    check_yql(field, "[1%3b]", 5)
    check_yql(field, "[1%3b>", 5)
    check_yql(field, "[%3b4]", 5)
    check_yql(field, "<%3b4]", 5)
    check_yql(field, "[%3b]", 5)
    check_yql(field, "<%3b>", 5)
    check_yql(field, "[1.0%3b1.7976931348623157E308]", 5)
  end

  def check_normal_ranges_standard(field)
    assert_hitcount("query=" + field + ":[1%3b2]", 3)
    assert_hitcount("query=" + field + ":[1.0%3b2.0]", 3)
    assert_hitcount("query=" + field + ":[1%3b4]", 5)
    assert_hitcount("query=" + field + ":[1%3b3]", 5)
    assert_hitcount("query=" + field + ":[1%3b]", 5)
    assert_hitcount("query=" + field + ":[%3b2]", 3)
  end

  def check_limited_ranges(field, support_range_limit)
    assert_hitcount("query=" + field + ":[1%3b2]", 3)
    assert_hitcount("query=" + field + ":[1%3b4]", 5)
    assert_hitcount("query=" + field + ":[1%3b3]", 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b1]", support_range_limit ? 2 : 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b2]", support_range_limit ? 2 : 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b3]", support_range_limit ? 3 : 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b4]", 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b400]", 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b-1]", support_range_limit ? 2 : 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b-2]", support_range_limit ? 2 : 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b-3]", support_range_limit ? 3 : 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b-4]", 5)
    assert_hitcount("query=" + field + ":[1%3b3%3b-400]", 5)
  end

  def check_range_optimizations
    # Singlevalue matches is optimized
    assert_hitcount('query=i1:%3E2%20i1:%3C4&type=all', 2)
    assert(search('query=i1:%3E2%20i1:%3C4&tracelevel=2&type=all').xmldata.match("Optimized query ranges"),
           "Query ranges are optimized")

    # Multivalue is not optimized
    assert_hitcount('query=m1:%3E2%20m1:%3C4&type=all', 2)
    assert(! search('query=m1:%3E2%20m1:%3C4&tracelevel=2&type=all').xmldata.match("Optimized query ranges"),
           "Query ranges are optimized")                                                                                                                                                     
  end

  def teardown
    stop
  end

end
