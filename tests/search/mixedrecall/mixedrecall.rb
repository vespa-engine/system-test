# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class MixedRecall < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test of mixed recall between index and attributes searching for sddocname")
  end

  def test_sddocname
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    vespa.start

    # this will wait for sddocname:music returning 10 hits
    feed_and_wait_for_docs("music", 10, {:file => selfdir+"/data/music-basic.json"})

    query = "query=bad"
    wait_for_hitcount(query, 5)
  end

  def teardown
    stop
  end

end
