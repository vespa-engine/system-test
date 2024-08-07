# Copyright Vespa.ai. All rights reserved.
require 'search_test'

module ContentSmokeCommon

  def start_feed_and_check
    start
    feed_and_check
  end

  def feed_and_check
    feed_only
    check
  end

  def check
    if @node
      @node.logctl2("visitor", "debug=on")
      @node.logctl2("searchvisitor.rankmanager", "debug=on")
      @node.logctl2("vsm.vsm-adapter", "debug=on")
    end
    assert_hitcount_with_timeout(5, "query=sddocname:music&streaming.selection=true", 10)
    assert_result_with_timeout(5, "query=sddocname:music&streaming.selection=true",
                              SearchTest::SEARCH_DATA+"music.10.result.json",
                              "title", ["title", "surl"])
  end

  def feed_only
    feed(:file => SearchTest::SEARCH_DATA+"music.10.json", :timeout => 240)
  end

  def verify_get(params = {})
    doc = vespa.document_api_v1.get("id:test:music::http://shopping.yahoo.com/shop?d=hab&id=1804905713", params)
    assert_equal("id:test:music::http://shopping.yahoo.com/shop?d=hab&id=1804905713", doc.documentid)
  end

end
