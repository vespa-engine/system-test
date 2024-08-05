# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class StructuredWeightedSetTest < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("search structured data in a Searcher")
  end

  def test_multivalue_data
    add_bundle(selfdir + "SimpleTestSearcher.java")
    searcher = Searcher.new("com.yahoo.test.SimpleTestSearcher")
    deploy_app(
      SearchApp.new.
        cluster_name("wstsc").
        sd(selfdir+"wstest.sd").
        container(Container.new("mycc").
                    search(Searching.new.
                             chain(Chain.new("default", "vespa").add(searcher))).
                    docproc(DocumentProcessing.new).
                    documentapi(ContainerDocumentApi.new)))
    start
    feed_and_wait_for_docs("wstest", 1, :file => selfdir+"feed-3.json")
    # save_result("query=titles:%22james%20bond%22", selfdir+"result.ws.json")
    assert_result("query=titles:%22james%20bond%22", selfdir+"result.ws.json")
  end

  def teardown
    stop
  end

end
