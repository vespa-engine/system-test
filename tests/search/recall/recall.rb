# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class Recall < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Test search using recall api")
    deploy_app(SearchApp.new.sd(selfdir + "recall.sd"))
    start
  end

  def test_recall
    feed_and_wait_for_docs("recall", 1, :file => selfdir + "recall.json")

    assert_recall(2, 2, "query=foo bar")
    assert_recall(2, 2, "query=foo&filter=%2bbar")
    assert_recall(1, 1, "query=foo&recall=%2bbar")
    assert_recall(1, 1, "query=foo&recall=-baz")
    assert_recall(1, 1, "query=foo&recall=%2bbar%2bbar")
    assert_recall(1, 1, "query=foo&recall=%2Bmyid:1")

    assert_approx(get_relevancy("query=foo"), get_relevancy("query=foo&recall=%2bbar"))
  end

  def assert_recall(matches, term_count, query)
    result = search(query)
    assert_equal(1, result.hit.size);
    exp = {"fieldMatch(title).matches" => matches, "queryTermCount" => term_count}
    assert_features(exp, result.hit[0].field['summaryfeatures'])
  end

  def get_relevancy(query)
    retval = search(query).hit[0].field["relevancy"].to_f
    puts "relevancy for '#{query}' = #{retval}"
    return retval
  end

  def teardown
    stop
  end

end
