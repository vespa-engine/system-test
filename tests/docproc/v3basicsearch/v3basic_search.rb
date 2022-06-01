# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
                                DocumentProcessor.new("com.yahoo.vespatest.WorstMusicDocProc"))))).
            logserver("node1").
            slobrok("node1").
            search(SearchCluster.new("worst").sd(DOCPROC + "data/worst.sd"))
    )
    start
  end

  def test_v3_basicsearch_docproc
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.xml", :cluster => "worst")
    assert_result("query=sddocname:worst", DOCPROC + "data/worst-processed.json")
    assert_result("query=title:worst", DOCPROC + "data/worst-processed.json")
    queue = assert_log_matches(/Starting message bus with max \d+? pending messages and max \d+?\.\d+? pending megabytes./, 60)
    assert_equal(1, queue)
  end

  def teardown
    stop
  end

end
