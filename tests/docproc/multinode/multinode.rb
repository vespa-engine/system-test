# Copyright Vespa.ai. All rights reserved.

require 'docproc_test'

class MultiNode < DocprocTest

  def initialize(*args)
    super(*args)
    @num_hosts = 3
  end

  def setup
    set_owner("gjoranv")
    add_bundle(DOCPROC + "/WorstMusicDocProc.java")
    deploy(selfdir + "app")
    start
  end

  def test_basicsearch_docproc_multinode
    set_expected_logged(Regexp.union(/Only 1 of 3 nodes are up and OK/,
                                     /Bad network connectivity/))
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json", :cluster => "music", :host => vespa.container.values.first.hostname)
    assert_result("query=sddocname:music", DOCPROC + "data/music.10.result.json", "surl")
  end


end
