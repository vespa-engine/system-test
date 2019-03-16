# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class FreshnessBoost < IndexedSearchTest

  def setup
  end

  def test_freshnessboost
    set_owner("geirst")
    set_description("Test freshnessboost ranking")
    deploy_app(SearchApp.new.sd(selfdir+"musicdate.sd"))
    start
    feed_and_wait_for_docs("musicdate", 10, :file => selfdir+"musicdate.10.xml")

    puts "Testing that the newests documents come first"
    assert_result("query=blues&datetime=19678000", selfdir+"modelblues.result", nil, ["title"])

    puts "Testing that freshnessboost can be turned off on a per-query basis (now -> old documents -> freshness = 0)"
    assert_not_queries_match("query=blues&datetime=19678000", "query=blues&datetime=now", /relevancy/)
  end

  def teardown
    stop
  end

end
