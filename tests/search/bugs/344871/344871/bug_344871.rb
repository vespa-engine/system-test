# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bug_344871 < IndexedSearchTest

  def nightly?
    true
  end

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd("#{selfdir}/simple.sd"))
    start
  end

  def test_bold_doublewidth
    feed_and_wait_for_docs("simple", 2, :file => "#{selfdir}/input.xml",
                           :skipfeedtag => true)

    # "Query: basic test"
    assert_result("query=test", 
                  "#{selfdir}/result1.xml", "surl")

    # "Query: singlewidth title"
    assert_result("query=ON", 
                  "#{selfdir}/result2.xml", "surl")

    # "Query: doublewidth title"
    assert_result("query=%EF%BC%AF%EF%BC%AE",
                  "#{selfdir}/result2.xml", "surl")

    # "Query: singlewidth description (via juniper)"
    assert_result("query=SONY",
                  "#{selfdir}/result3.xml", "surl")

    # "Query: doublewidth description (via juniper)"
    assert_result("query=%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9",
                   "#{selfdir}/result3.xml", "surl")
  end

  def teardown
    stop
  end

end
