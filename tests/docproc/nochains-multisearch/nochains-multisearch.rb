# Copyright Vespa.ai. All rights reserved.

require 'docproc_test'
require 'app_generator/container_app'

class NoChainsMultiSearch < DocprocTest

  def setup
    set_owner("gjoranv")
    add_bundle(selfdir + "AppleDocProc.java")
    add_bundle(selfdir + "BananaDocProc.java")
    deploy_app(
        ContainerApp.new.
            container(
            Container.new("default").
                search(Searching.new).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)
        ).
            container(
            Container.new("musicindexingcluster").
                docproc(DocumentProcessing.new.chain(
                            Chain.new("musicindexing", "indexing").add(
                                DocumentProcessor.new("com.yahoo.vespatest.AppleDocProc", "indexingStart")))).
                http(Http.new().server(Server.new("myServer", 4081)))
        ).
            container(
            Container.new("muzakindexingcluster").
                docproc(DocumentProcessing.new.chain(
                            Chain.new("muzakindexing", "indexing").add(
                                DocumentProcessor.new("com.yahoo.vespatest.BananaDocProc", "indexingStart")))).
                http(Http.new().server(Server.new("myServer", 4082)))
        ).
            logserver("node1").
            slobrok("node1").
            search(SearchCluster.new("music").sd(selfdir+"music.sd").
                       indexing("musicindexingcluster").
                       indexing_chain("musicindexing")).
            search(SearchCluster.new("muzak").sd(selfdir+"muzak.sd").
                       indexing("muzakindexingcluster").
                       indexing_chain("muzakindexing"))
    )
    start
  end

  def test_nochains_multisearch
    feed_and_wait_for_docs("music", 4, :file => selfdir+"music.4.json", :cluster => "music")
    assert_result("query=sddocname:music", selfdir + "music.4.result.json")

    feed_and_wait_for_docs("muzak", 4, :file => selfdir+"muzak.4.json", :cluster => "muzak")
    assert_result("query=sddocname:muzak", selfdir + "muzak.4.result.json")

    assert_result("query=title:title", selfdir + "title.result.json")
  end

  def teardown
    stop
  end

end
