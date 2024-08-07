# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SearchDownWhileFeeding < IndexedStreamingSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test that we get an error when search is down while feeding, but ok when search is up again")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_stop_search
    puts "Feeding when all is up"
    result = feedfile(selfdir+"music.json", :client => :vespa_feed_client)
    assert_match(/\"feeder.ok.count\" : 10/, result)

    vespa.search["search"].first.stop
    sleep(10)

    result = feedfile(selfdir+"music.json", { :client => :vespa_feed_client, :exceptiononfailure => false, :timeout => 10 })

    assert_match(/\"feeder.error.count\" : 10/, result)

    vespa.search["search"].first.start

    result = feedfile(selfdir+"music.json", { :client => :vespa_feed_client, :exceptiononfailure => false})
    assert_match(/\"feeder.ok.count\" : 10/, result)
  end

  def teardown
    stop
  end

end
