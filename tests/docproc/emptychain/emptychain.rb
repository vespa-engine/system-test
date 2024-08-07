# Copyright Vespa.ai. All rights reserved.
require 'docproc_test'

class EmptyChain < DocprocTest

  def setup
    set_owner("arnej")
    deploy(selfdir + "app")
    start
  end

  def test_emptychain
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC+"data/worst-input.json", :cluster => "worst")
    assert_result("query=sddocname:worst", DOCPROC + "data/worst-output.json")
  end

  def teardown
    stop
  end

end
