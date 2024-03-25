# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Bug_344871 < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start
  end

  def test_bold_doublewidth
    feed_and_wait_for_docs("simple", 2, :file => "#{selfdir}/input.json")

    # "Query: basic test"
    assert_result("query=test", 
                  "#{selfdir}/result1.json", "surl")

    # "Query: singlewidth title"
    assert_result("query=ON", 
                  "#{selfdir}/result2.json", "surl")

    # "Query: doublewidth title"
    assert_result("query=%EF%BC%AF%EF%BC%AE",
                  "#{selfdir}/result2.json", "surl")

    # "Query: singlewidth description (via juniper)"
    assert_result("query=SONY",
                  "#{selfdir}/result3.json", "surl")

    # "Query: doublewidth description (via juniper)"
    assert_result("query=%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9",
                   "#{selfdir}/result3.json", "surl")
  end

  def teardown
    stop
  end

end
