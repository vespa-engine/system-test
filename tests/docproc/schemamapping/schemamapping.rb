# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'

class SchemaMapping < DocprocTest

  def setup
    set_owner("musum")
    add_bundle(selfdir + "AppleDocProc.java")
    add_bundle(selfdir + "BananaDocProc.java")
    add_bundle(selfdir + "PearDocProc.java")
    add_bundle(selfdir + "MelonDocProc.java")
    deploy(selfdir + "app")
    start
  end

  def test_schemamapping_basic
    feed_and_wait_for_docs("simple", 2, :file => selfdir+"simple.json", :cluster => "simple", :route => "\"default/chain.apple default/chain.banana indexing\"")
    assert_hitcount("query=title:Apple", 2)
    assert_hitcount("query=title:Banana", 2)
    feed(:file => selfdir+"simpleupdate.json", :cluster => "simple", :route => "\"default/chain.apple indexing\"")
    wait_for_hitcount("query=isbn:Pear", 2)
  end


end
