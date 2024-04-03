# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class StructuredArrayTest < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("search structured data in a Searcher")
  end

  def test_multivalue_data
    add_bundle(selfdir + "SimpleTestSearcher.java")
    searcher = Searcher.new("com.yahoo.test.SimpleTestSearcher")
    deploy_app(
      SearchApp.new.
        cluster_name("multitest").
        sd(selfdir+"mvdtest.sd").
        container(Container.new("mycc").
                    search(Searching.new.
                             chain(Chain.new("default", "vespa").add(searcher))).
                    docproc(DocumentProcessing.new)))
    start
    feed_and_wait_for_docs("mvdtest", 1, :file => selfdir+"feed-1.json")
    # save_result("query=titles:%22slim%20shady%22", selfdir+"result.ss.json")
    assert_result("query=titles:%22slim%20shady%22", selfdir+"result.ss.json")
  end

  def teardown
    stop
  end

end
