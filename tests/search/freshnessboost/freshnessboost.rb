# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class FreshnessBoost < IndexedStreamingSearchTest

  def setup
  end

  def test_freshnessboost
    set_owner("geirst")
    set_description("Test freshnessboost ranking")
    deploy_app(SearchApp.new.sd(selfdir+"musicdate.sd"))
    start
    feed_and_wait_for_docs("musicdate", 10, :file => selfdir+"musicdate.10.json")

    puts "Testing that the newests documents come first"
    assert_result("query=blues&datetime=19678000", selfdir+"modelblues.result.json", nil, ["title"])

    puts "Testing that freshnessboost can be turned off on a per-query basis (now -> old documents -> freshness = 0)"
    resa = search("query=blues&datetime=19678000")
    resb = search("query=blues&datetime=now")
    resa.hit.each do |h|
      assert(h.field['relevancy'] > 500, "Got: #{h}")
    end
    resb.hit.each do |h|
      assert(h.field['relevancy'] < 100, "Got: #{h}")
    end
    sfa = resa.hit[0].field['summaryfeatures']
    sfb = resb.hit[0].field['summaryfeatures']
    assert(sfa['freshness(docdate)'] > 0.9, "Got: #{sfa}")
    assert(sfb['freshness(docdate)'] < 0.1, "Got: #{sfb}")
  end


end
