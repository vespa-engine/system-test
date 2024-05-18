# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'
require 'app_generator/container_app'

class V3BasicDocproc < SearchContainerTest

  def setup
    set_owner("arnej")
    add_bundle(DOCPROC + "v3docprocs/WorstMusicDocProc.java")

    deploy_app(
        ContainerApp.new.container(
            Container.new("default").
                search(Searching.new).
                docproc(DocumentProcessing.new.chain(
                            Chain.new("default").add(
                              DocumentProcessor.new("com.yahoo.vespatest.WorstMusicDocProc")))).
                          documentapi(ContainerDocumentApi.new)))
            logserver("node1").
            slobrok("node1").
            search(SearchCluster.new("worst").sd(DOCPROC + "data/worst.sd"))
    )
    start
  end

  def test_v3_basicsearch_docproc
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.json", :cluster => "worst")
    assert_result("query=sddocname:worst", DOCPROC + "data/worst-processed.json")
    assert_result("query=title:worst", DOCPROC + "data/worst-processed.json")
  end

  def teardown
    stop
  end

end
