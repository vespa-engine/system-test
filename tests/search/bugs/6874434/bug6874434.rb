# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
    vespa.adminserver.execute("vespa-visit --xmloutput")
    #     save_result("query=title:test&streaming.userid=27959&format=xml", selfdir+"result.xml")
    assert_xml_result_with_timeout(2.0, "query=title:test&streaming.userid=27959", selfdir+"result.xml")
    # save_result("query=title:test&streaming.userid=27959", selfdir+"result.json")
    assert_result_with_timeout(2.0, "query=title:test&streaming.userid=27959", selfdir+"result.json")
  end

  def teardown
    stop
  end

end
