# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ReindexUptime < IndexedStreamingSearchTest

  def setup
    set_description("Description: Test that Vespa is up during reindexing")
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
        # We accept missing hits because when replacing documents in the memory index
        # we might not hit all documents if the search arrives just between removals and insertions.
        assert(hits >= 0 && hits <= 40, "Unexpected number of hits: #{hits}")
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
