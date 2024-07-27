# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class OpenNlpLinguistics < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests Chinese segmentation with the OpenNlp linguistics module")
  end

  def make_app
    app = SearchApp.new
    container = Container.new('container').search(Searching.new)
                  .docproc(DocumentProcessing.new)
                  .documentapi(ContainerDocumentApi.new)
                  .component(Component.new('com.yahoo.language.opennlp.OpenNlpLinguistics'))
                  .config(ConfigOverride.new('ai.vespa.opennlp.open-nlp').
                          add('cjk', 'true').
                          add('createCjkGrams', 'true'))

    app.container(container)
    app.indexing_cluster('container')
    app.sd(selfdir + 'app/schemas/test.sd')
    app
  end

  def test_simple_linguistics
    deploy_app(make_app)
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "documents.json")

    assert_hitcount("query=text:展示", 1) # A Chinese token from the resulting segmentation done
    assert_hitcount("query=text:run", 1) # English is still stemmed
   end

  def teardown
    stop
  end

end
