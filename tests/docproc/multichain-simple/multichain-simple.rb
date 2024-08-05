# Copyright Vespa.ai. All rights reserved.

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
    options = { :cluster => "worst", :port => 4090 }
    worst_input = DOCPROC + "data/worst-input.json"
    worst_remove = DOCPROC + "data/worst-remove.json"

    feed_and_wait_for_docs("worst", 4, options.merge({:file => worst_input}))
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-default.json")
    feed_and_wait_for_docs("worst", 0, options.merge({:file => worst_remove}))

    feed_and_wait_for_docs("worst", 4, options.merge({:file => worst_input, :route => "\"banana/chain.split indexing\""}))
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-banana.json")
    feed_and_wait_for_docs("worst", 0, options.merge({:file => worst_remove, :route => "\"banana/chain.split indexing\""}))

    feed_and_wait_for_docs("worst", 4, options.merge({:file => worst_input, :route => "\"container/chain.apple indexing\""}))
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-apple.json")
    feed_and_wait_for_docs("worst", 0, options.merge({:file => worst_remove, :route => "\"container/chain.apple indexing\""}))

    feed_and_wait_for_docs("worst", 4, options.merge({:file => worst_input, :route => "\"container/chain.default banana/chain.split container/chain.apple indexing\""}))
    assert_result("query=sddocname:worst&nocache", selfdir + "simple-result-all.json")
  end

  def teardown
    stop
  end

end
