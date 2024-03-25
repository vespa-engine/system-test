# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class ReindexUptime < IndexedStreamingSearchTest

  def setup
    set_description("Description: Test that VESPA is up during reindexing")
    set_owner("yngve")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_reindex_uptime
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.json")

    wait_for_hitcount("query=frank", 40);

    done = false
    thread = Thread.new do
      while !done
        hits = search("query=frank").hitcount
        # We accept one missing hit because when replacing a document in the memory index
        # we might not hit that document if the search arrives just between removal and insertion.
        assert(hits >= 39 && hits <= 40, "Unexpected number of hits: #{hits}")
      end
    end

    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.json")

    done = true
    thread.join
    assert_hitcount("query=frank", 40);
  end

  def teardown
    stop
  end

end
