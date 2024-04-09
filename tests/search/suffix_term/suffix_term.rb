# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

  def teardown
    stop
  end

end
