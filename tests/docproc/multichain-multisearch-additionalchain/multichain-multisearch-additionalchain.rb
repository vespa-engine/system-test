# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'docproc_test'
require 'app_generator/container_app'

class MultiChainMultiSearchAdditionalChain < DocprocTest

  def setup
    set_owner("gjoranv")
    add_bundle(DOCPROC + "WorstMusicDocProc.java")
    add_bundle(selfdir + "AppleDocProc.java")
    add_bundle(selfdir + "BananaDocProc.java")
    add_bundle(selfdir + "JallaDocProc.java")
    deploy_app(
               ContainerApp.new.
               container(
                         Container.new("default").
                         search(Searching.new).
                         docproc(DocumentProcessing.new.
                                 chain(Chain.new("default").add(
                                    DocumentProcessor.new("com.yahoo.vespatest.WorstMusicDocProc"))).
                                 chain(Chain.new("jalla").add(
                                    DocumentProcessor.new("com.yahoo.vespatest.JallaDocProc"))).
                                 chain(Chain.new("musicindexing", "indexing").add(
                                    DocumentProcessor.new("com.yahoo.vespatest.AppleDocProc", "indexingStart"))).
                                 chain(Chain.new("muzakindexing", "indexing").add(
                                    DocumentProcessor.new("com.yahoo.vespatest.BananaDocProc", "indexingStart")))
                                 )).
               logserver("node1").
               slobrok("node1").
               search(SearchCluster.new("music").sd(selfdir + "music.sd").
                      indexing("default").
                      indexing_chain("musicindexing")).
               search(SearchCluster.new("muzak").sd(selfdir + "muzak.sd").
                      indexing("default").
                      indexing_chain("muzakindexing"))
    )
    start
  end

  def test_multichain_multisearch_additionalchain
    feed_and_wait_for_docs("music", 4, :file => selfdir+"music.4.xml", :cluster => "music", :route => "\"default/chain.default default/chain.jalla indexing\"")
    assert_result("query=sddocname:music", selfdir + "music.4.result.json")

    feed_and_wait_for_docs("muzak", 4, :file => selfdir+"muzak.4.xml", :cluster => "muzak", :route => "\"default/chain.default default/chain.jalla indexing\"")
    assert_result("query=sddocname:muzak", selfdir + "muzak.4.result.json")
  end

  def teardown
    stop
  end

end
