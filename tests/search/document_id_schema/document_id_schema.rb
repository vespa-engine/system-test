# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class DocumentIdSchema < IndexedStreamingSearchTest

  def setup
    set_owner("vekterli")
  end

  def test_document_id_schema
    set_description("Test document id schema")
    deploy_app(SearchApp.new.cluster(SearchCluster.new('test').
                                     sd(selfdir + "test.sd")))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.json")
    assert_hitcount("f1:c", 2)
  end

  def teardown
    stop
  end

end
