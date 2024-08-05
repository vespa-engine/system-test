# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class IndexWeightedSets < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Check indexing of weighted sets behaves like term boost used to do.")
    deploy_app(SearchApp.new.sd(selfdir + "settest.sd"))
    start
    feed_and_wait_for_docs("settest", 2, :file => selfdir + "settest.json")
  end

  def test_indexweightedsets
    # assert equal rank
    query = "/?query=marker:d&skipnormalizing&format=xml"
    result = search(query)
    assert result.xml.elements[1].attributes['relevancy'] == result.xml.elements[2].attributes['relevancy']

    # assert unequal rank and correct order
    query = "/?query=weight:a&skipnormalizing&ranking=weight&format=xml"
    result = search(query)
    assert result.xml.elements[1].attributes['relevancy'] != result.xml.elements[2].attributes['relevancy']
    hit1 = result.xml.elements["hit[1]/field[@name='marker']"].get_text.to_s
    hit2 = result.xml.elements["hit[2]/field[@name='marker']"].get_text.to_s
    assert_equal("dok2", hit1[0,4], "Expected different result ordering.")
    assert_equal("dok1", hit2[0,4], "Expected different result ordering.")
    assert_equal(result.xml.elements[1].attributes['relevancy'].to_i, 10)
    assert_equal(result.xml.elements[2].attributes['relevancy'].to_i, 1)

    # assert unequal rank and correct order
    query = "/?query=weight:b&skipnormalizing&ranking=weight&format=xml"
    result = search(query)
    assert result.xml.elements[1].attributes['relevancy'] != result.xml.elements[2].attributes['relevancy']
    hit1 = result.xml.elements["hit[1]/field[@name='marker']"].get_text.to_s
    hit2 = result.xml.elements["hit[2]/field[@name='marker']"].get_text.to_s
    assert_equal("dok1", hit1[0,4], "Expected different result ordering.")
    assert_equal("dok2", hit2[0,4], "Expected different result ordering.")
    assert_equal(result.xml.elements[1].attributes['relevancy'].to_i, 10)
    assert_equal(result.xml.elements[2].attributes['relevancy'].to_i, 1)

    assert_hitcount("query=tokenized:2011", 2)
    assert_hitcount("query=other_ratings:year=2011,highest_rate///", 2)
    assert_hitcount("query=critics_ratings:%22year=2011,name=other+critic+yy%22", 1)
    assert_hitcount("query=critics_ratings:%22year=2011,name=critic_X%22", 1)
  end

  def teardown
    stop
  end

end
