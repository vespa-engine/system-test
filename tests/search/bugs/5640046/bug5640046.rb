# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class Bug5640046 < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    set_description("Test for bug 5640046, invalid document ids in index")
  end

  def test_bug5640046
    deploy_app(SearchApp.new.sd(selfdir+"sd1/test.sd"))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.1.xml")

    # create a disk index
    vespa.search["search"].first.trigger_flush
    assert_log_matches(/.*flush\.complete.*memoryindex.*flush\.1/, 60)

    # remove id:test:test::2
    feed(:file => selfdir + "feed.2.xml")
    wait_for_hitcount("f1:foo", 1)

    # redeploy with new field
    output = redeploy(SearchApp.new.sd(selfdir+"sd2/test.sd"))
    wait_for_application(vespa.container.values.first, output)

    # trigger flush
    vespa.search["search"].first.trigger_flush

    # restart to trigger replay from transaction log
    vespa.search["search"].first.restart
    wait_for_hitcount("sddocname:test", 1)
    assert_hitcount("f1:foo", 1)
  end

  def teardown
    stop
  end

end
