# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ImmediateFeeding < IndexedStreamingSearchTest

  def setup
    set_owner("valerijf")
    set_description("Tests that feeding immediately after vespa starts works. This testcase " +
                    "does not use any methods that sleeps or waits for services to start.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    vespa.start
  end

  def test_immediate_feeding
    # Note: Explicitly use vespa-feeder, since vespa-feed-client will fail when services are not up when starting to feed
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA + "music.10.json", :client => :vespa_feeder, :maxretries => "5")
    check_fields=['bgnsellers','categories','ew','mid','pto','surl','title']
    assert_result("query=sddocname:music", selfdir+"music.10.result.json", "title", check_fields)
  end


end
