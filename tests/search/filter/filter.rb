# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Filter < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Search using filter")
    deploy_app(SearchApp.new.sd(selfdir+"f.sd"))
    start
  end

  def test_filter
    feed_and_wait_for_docs("f", 7, :file => selfdir+"f.7.xml")

    puts "Sanity check"
    assert_hitcount("/?query=sddocname:f&type=all", 7)

    result = search("/?query=title:something+artist:foobar&type=all")
    assert_equal([ "5 foobar foobar",
                   "4 foobar",
                   "2 x x x x foobar",
                   "7 foobar foobar foobar" ].sort, result.get_field_array("artist").sort);
    # same with part of query in filter
    result = search("/?query=title:something&filter=%2Bartist:foobar&type=all")
    assert_equal([ "5 foobar foobar",
                   "4 foobar",
                   "2 x x x x foobar",
                   "7 foobar foobar foobar" ].sort, result.get_field_array("artist").sort);

    result = search("/?query=title:something%20-artist:foobar&type=all")
    assert_equal([ "1 whatever" ].sort, result.get_field_array("artist").sort)


    # simple query, no filter
    result = search("/?query=title:same&type=all")
    assert_equal(5, result.hit.size)
    result.sort_results_by("artist")

    nofilterid = result.get_field_array("documentid")
    nofilterrelevance = result.get_field_array("relevancy")

    result = search("/?query=title:same&filter=artist:foobar&type=all")
    assert_equal(5, result.hit.size)

    filterid = result.get_field_array("documentid")
    filterrelevance = result.get_field_array("relevancy")

    # The filter had only a rank term, so no change in recall
    assert_equal(nofilterid.size, filterid.size)

    # if filter works the results should have different rank values,
    # and thus the order or at least the associated relevancies should
    # change

    results_have_equal_order_and_relevance = true

    (0..(filterid.size - 1)).each do |i|
      if (filterid[i] == nofilterid[i]) && (filterrelevance[i] == nofilterrelevance[i])
        results_have_equal_order_and_relevance &= true
      else
        results_have_equal_order_and_relevance = false
      end
    end

    assert_equal(false, results_have_equal_order_and_relevance)
  end

  def teardown
    stop
  end

end
