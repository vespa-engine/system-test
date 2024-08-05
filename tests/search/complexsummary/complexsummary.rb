# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class ComplexSummary < IndexedStreamingSearchTest
  
  def setup
    set_owner("musum")
  end
  
  def test_complex_summary
    deploy_app(SearchApp.new.sd(selfdir + "complexsummary.sd"))
    start
    feed(:file => selfdir + "doc.json")
    wait_for_hitcount("query=sddocname:complexsummary", 2)
    check_fields = [ 'nallestruct', 'nallestructarray', 'title' ]
    assert_result("/search/?query=title:Title1", selfdir+"res1.json", nil, check_fields)
    assert_result("/search/?query=title:Title2", selfdir+"res2.json", nil, check_fields)
  end

  def teardown
    stop
  end
  
end
