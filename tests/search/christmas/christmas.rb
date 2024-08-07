# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class Christmas < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Ensure that 'Christmas' and 'christmas' is indexed equally.")
    deploy_app(SearchApp.new.sd(selfdir+"jul.sd"))
    start
    feed_and_wait_for_docs("jul", 2, :file => selfdir + "feed.json")
  end

  def test_symmetric_lowercasing
    # Assert hit counts to check the test passes for the right reason
    assert_hitcount("/?query=ribbe:Christmas", 2)
    assert_hitcount("/?query=ribbe:christmas", 2)
    assert_hitcount("/?query=ribbe:christmas+ribbe:Christmas", 2)
  end

  def teardown
    stop
  end

end
