# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ZeroHits < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Do a query where hits=0")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_zerohits
    feed_and_wait_for_docs("music", 2, :file => selfdir+"input.xml")

    puts "Running query to see that doc is searchable"
    assert_result_matches("query=metallica&hits=0",
                          selfdir+"zerohits.result",
                          "total-hit-count")

    puts "Search for docs in the normal way"
    assert_result("query=metallica", selfdir+"1m.result")
    assert_result("query=cure",      selfdir+"1c.result")

    puts "Search for docs with zero hits"
    assert_result("query=metallica&hits=0", selfdir+"0.result")
    assert_result("query=metallica&hits=0", selfdir+"0.result")
    assert_result("query=metallica&hits=0&nocache", selfdir+"0.result")

    assert_result("query=cure&hits=0", selfdir+"0.result")
    assert_result("query=cure&hits=0", selfdir+"0.result")
    assert_result("query=cure&hits=0&nocache", selfdir+"0.result")

  end

  def teardown
    stop
  end

end
