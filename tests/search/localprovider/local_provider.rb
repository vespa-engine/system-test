# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class LocalProvider < IndexedStreamingSearchTest

  def setup
    set_owner("baldersheim")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
                      search_chain(
                        Provider.new("local-provider", "local").cluster("search")))
    start
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json", :timeout => 240)
  end

  def test_search_localprovider
    assert_result("query=sddocname:music&sources=local-provider",
                   SEARCH_DATA+"music.10.result.json",
                   "title", [ "title", "surl", "mid" ])
  end

  def test_implicit_provider_not_created_when_configuring_localprovider
    assert_hitcount("query=sddocname:music&sources=search", 0)
  end

  def teardown
    stop
  end

end
