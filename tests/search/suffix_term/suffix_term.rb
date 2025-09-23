# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class SuffixTerm < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_suffix_term
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.json")
    assert_hitcount("query=*test&nocache", 5)
  end


end
