# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'docproc_test'

class MultiChainSimple < DocprocTest

  def setup
    set_owner("gjoranv")
    add_bundle(DOCPROC + "WorstMusicDocProc.java")
    add_bundle(selfdir + "AppleDocProc.java")
    add_bundle(selfdir + "BananaDocProc.java")
    deploy(selfdir + "setup-1x1", DOCPROC + "data/worst.sd")

    start
  end

  def test_multichain_simple
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC+"data/worst-input.xml", :cluster => "worst")
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-default.json")
    feed_and_wait_for_docs("worst", 0, :file => DOCPROC+"data/worst-remove.xml", :cluster => "worst")

    feed_and_wait_for_docs("worst", 4, :file => DOCPROC+"data/worst-input.xml", :cluster => "worst", :route => "\"banana/chain.split indexing\"")
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-banana.json")
    feed_and_wait_for_docs("worst", 0, :file => DOCPROC+"data/worst-remove.xml", :cluster => "worst", :route => "\"banana/chain.split indexing\"")

    feed_and_wait_for_docs("worst", 4, :file => DOCPROC+"data/worst-input.xml", :cluster => "worst", :route => "\"container/chain.apple indexing\"")
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-apple.json")
    feed_and_wait_for_docs("worst", 0, :file => DOCPROC+"data/worst-remove.xml", :cluster => "worst", :route => "\"container/chain.apple indexing\"")

    feed_and_wait_for_docs("worst", 4, :file => DOCPROC+"data/worst-input.xml", :cluster => "worst", :route => "\"container/chain.default banana/chain.split container/chain.apple indexing\"")
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-all.json")
  end

  def teardown
    stop
  end

end
