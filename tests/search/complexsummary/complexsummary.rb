# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class ComplexSummary < IndexedSearchTest
  
  def setup
    set_owner("musum")
  end
  
  def test_complex_summary
    deploy_app(SearchApp.new.sd(selfdir + "complexsummary.sd"))
    start
    feed(:file => selfdir + "doc.xml")
    wait_for_hitcount("query=sddocname:complexsummary", 2)
    assert_result("/search/?query=title:Title1", selfdir+"res1.json")
    assert_result("/search/?query=title:Title2", selfdir+"res2.json")
  end

  def teardown
    stop
  end
  
end
