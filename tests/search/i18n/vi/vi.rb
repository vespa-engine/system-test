# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Vi < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Test of Vietnamese indexing and query phrasing")
    deploy_app(SearchApp.new.sd("#{selfdir}/vietnamese.sd"))
    start
  end

  def test_vietnamese_deaccent
    feed_and_wait_for_docs("vietnamese", 3, :file => "#{selfdir}/vietnamese.xml")

    # accented query
    assert_hitcount_with_timeout(10, 'query=%C3%A2m%20d%C6%B0%C6%A1ng%20l%E1%BB%8Bch%20vi%E1%BB%87t%20nam&language=vi&type=all', 2)

    # accented query, no language parameter
    assert_hitcount_with_timeout(10, 'query=%C3%A2m%20d%C6%B0%C6%A1ng%20l%E1%BB%8Bch%20vi%E1%BB%87t%20nam&type=all', 2)

    # normalized query
    assert_hitcount_with_timeout(10, 'query=am%20duong%20lich%20viet%20nam&language=vi&type=all', 2)
  end

  def teardown
    stop
  end

end
