# Copyright Vespa.ai. All rights reserved.

require 'streaming_search_test'

class PositionsBug < StreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("verify bugfix")
  end


  def test_bug6874434
    deploy_app(SearchApp.new.
                 sd(selfdir + 'app/schemas/test.sd'))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir+"feed.json")
    vespa.adminserver.execute("vespa-visit")
    # save_result("query=title:test&streaming.userid=27959", selfdir+"result.json")
    assert_result_with_timeout(2.0, "query=title:test&streaming.userid=27959", selfdir+"result.json")
  end

  def teardown
    stop
  end

end
