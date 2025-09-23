# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'

class OneContainer < DocprocTest

  def setup
    set_owner("bratseth")
    add_bundle(DOCPROC + "v3docprocs/WorstMusicDocProc.java")
    deploy(selfdir + "app")
    start
  end

  def test_onecontainer
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.json", :cluster => "worst")
    assert_result("query=sddocname:worst", DOCPROC + "data/worst-processed.json")
    assert_result("query=title:worst", DOCPROC + "data/worst-processed.json")
  end


end
