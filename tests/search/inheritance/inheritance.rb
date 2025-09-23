# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Inheritance < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test feeding/indexing of both sub- and supertype documents")
  end

  # Multiple clusters inherit from same base sd
  def test_multiple_inherit_same_base
    deploy_app(SearchApp.new.sd(selfdir + "app2/multimedia.sd").cluster(
                        SearchCluster.new("mp3").
                        sd(selfdir + "app2/mp3.sd").
                        indexing("dp")).
                      cluster(
                        SearchCluster.new("image").
                        sd(selfdir + "app2/image.sd").
                        indexing("dp")).
                      container(Container.new("dp").
                        search(Searching.new).
                        docproc(DocumentProcessing.new).
                        documentapi(ContainerDocumentApi.new)))
    start
    feed_and_wait_for_docs("mp3", 1, :file => selfdir+"onemp3.json", :cluster => "mp3")
    feed_and_wait_for_docs("image", 1, :file => selfdir+"oneimage.json", :cluster => "image")
    wait_for_hitcount("query=rida&search=mp3", 1)
    wait_for_hitcount("query=make:foo&search=image", 1)
    assert_hitcount("query=rida&search=mp3", 1)
    assert_result("query=rida&search=mp3", selfdir+"rida.result.json")
    if not is_streaming
      # URI search not supported in streaming
      assert_hitcount("query=uri.path:path&search=mp3", 1)
      assert_hitcount("query=site:foo.bar.com&search=mp3", 1)
      assert_hitcount("query=uri.path:path&search=image", 0)
      assert_hitcount("query=site:foo.bar.com&search=image", 0)
    end
    assert_result("query=make:foo&search=image", selfdir+"foo.result.json")
  end


end
