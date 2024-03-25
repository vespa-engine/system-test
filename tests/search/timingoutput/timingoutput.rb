# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class TimingOutput < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    # TODO: find something to test that's still robust on factory
    set_description("Check timing output does not disappear.");
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10, { :file => SEARCH_DATA+"music.10.xml" })
  end

  def test_timing_is_emitted
    result = search("/?query=blues&hits=1&presentation.timing&format=xml")
    assert_match("querytime=", result.xmldata)
    assert_match("summaryfetchtime=", result.xmldata)
    assert_match("searchtime=", result.xmldata)
  end

  def teardown
    stop
  end

end
