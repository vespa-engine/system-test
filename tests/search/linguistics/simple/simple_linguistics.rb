# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SimpleLinguistics < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that we can specify using the simple linguistcs implementation")
  end

  def make_app
    app = SearchApp.new
    container = Container.new('container').search(Searching.new)
                  .docproc(DocumentProcessing.new)
                  .documentapi(ContainerDocumentApi.new)
                  .component(Component.new('com.yahoo.language.simple.SimpleLinguistics'))
    app.container(container)
    app.indexing_cluster('container')
    app.sd(selfdir + 'app/schemas/test.sd')
    app
  end

  def test_simple_linguistics
    deploy_app(make_app)
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "documents.json")

    # simple linguistics (kstem) does not stem 'run' and 'running' to the same stem
    assert_hitcount("query=text:run", 1)
    assert_hitcount("query=text:running", 1)
   end

  def teardown
    stop
  end

end
