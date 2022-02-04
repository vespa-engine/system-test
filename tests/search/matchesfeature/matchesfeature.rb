# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class MatchesFeature < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_matches
    set_description("Test the matches feature")
    deploy_app(SearchApp.new.sd(selfdir+"matches.sd"))
    start
    feed_and_wait_for_docs("matches", 1, :file => selfdir + "matches.xml")

    verify_matches
    verify_matchcount
  end

  def verify_matches
    assert_matches({"matches(f1)" => 1}, "query=a")
    assert_matches({"matches(f1)" => 1}, "query=b")
    assert_matches({"matches(f1)" => 0}, "query=c")
    assert_matches({"matches(f1)" => 1}, "query=\"a b\"")
    assert_matches({"matches(f1,0)" => 1, "matches(f1,1)" => 0}, "query=b+c")

    assert_matches({"matches(f2)" => 0}, "query=a")
    assert_matches({"matches(f2)" => 1}, "query=b")
    assert_matches({"matches(f2)" => 1}, "query=c")
    assert_matches({"matches(f2)" => 1}, "query=\"b c\"")
    assert_matches({"matches(f2,0)" => 0, "matches(f2,1)" => 1}, "query=a+b")

    assert_matches({"matches(f3)" => 0}, "query=a")
    assert_matches({"matches(f3)" => 1}, "query=f3:a")
    assert_matches({"matches(f3,0)" => 0, "matches(f3,1)" => 1}, "query=a+f3:a")
  end

  def verify_matchcount
    assert_matches({"matchCount(f1)" => 1}, "query=a")
    assert_matches({"matchCount(f1)" => 1}, "query=b")
    assert_matches({"matchCount(f1)" => 0}, "query=c")
    assert_matches({"matchCount(f1)" => 1}, "query=d")
    assert_matches({"matchCount(f1)" => 1}, "query=(a+x)")
    assert_matches({"matchCount(f1)" => 2}, "query=a+d")
    assert_matches({"matchCount(f1)" => 2}, "query=a d")
    assert_matches({"matchCount(f1)" => 1}, "query=\"a b\"")
    assert_matches({"matchCount(f1)" => 3}, "query=(a+d+b)")
    assert_matches({"matchCount(f1)" => 3}, "query=a b d")
  end

  def assert_matches(expected, query)
    query = query + "&streaming.userid=1"
    result = search(query)
    assert_features(expected, JSON.parse(result.hit[0].field["summaryfeatures"]), 1e-4)
  end

  def teardown
    stop
  end

end
