# Copyright Vespa.ai. All rights reserved.

require 'docproc_test'

class ProcessRemoves < DocprocTest

  def setup
    set_owner("havardpe")
    add_bundle(selfdir+"src/RemoveProcessor.java")
    deploy(selfdir+"setup-1x1", DOCPROC+"data/worst.sd")
    start
  end

  def test_processremoves
    #feed 10 docs
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC+"data/worst-input.json", :cluster => "worst")
    assert_result("query=sddocname:worst&nocache", selfdir+"worst.4.result.json")

    #delete 1 doc
    feed_and_wait_for_docs("worst", 3, :file => selfdir+"removefirst.json", :cluster => "worst")
    #assert that we have 3 docs now
    assert_result("query=sddocname:worst&nocache", selfdir+"worst.3.result.json")

    #delete 1 doc, but set DocumentStatus.SKIP
    feed_and_wait_for_docs("worst", 3, :file => selfdir+"removesecond.json", :cluster => "worst")
    #assert that we still have 3 docs
    assert_result("query=sddocname:worst&nocache", selfdir+"worst.3.result.json")
  end

  def teardown
    stop
  end

end
