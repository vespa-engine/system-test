# -*- coding: utf-8 -*-
# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Bug5707026 < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Test for bug 5707026, unmatched <hi> in dynamic summary (juniper) field")
  end

  def test_bug5707026
    deploy_app(SearchApp.new.sd(selfdir+"site.sd"))
    start
    feed_and_wait_for_docs("site", 1, :file => selfdir+"feed.json")

    query = "(yahoo ) OR (qterms:yahoo @@@) OR (weightedtags:yahoo @@@) OR (anchor:yahoo ) OR (keywords:yahoo ) OR (breadcrumb:yahoo ) OR (title2:yahoo ) OR (title3:yahoo ) OR (catarr1:yahoo ) OR (uri:yahoo ) OR (person:yahoo ) AND&type=adv"
    wait_for_hitcount(query, 1)
    exp_body_indexed = "<hi>Yahoo</hi>! Korea is lucky to have<sep />Choi, a project manager on the <hi>Yahoo</hi>! Custom Brand<sep />of a volunteer organization outside <hi>Yahoo</hi>!. He told me that altruistic<sep />"
    exp_body_streaming = "<hi>Yahoo</hi>! Korea is lucky to have several employees who are not just dedicated to <hi>Yahoo</hi>!, but to the betterment of their communities. Some write<sep />with joy for meeting me in real life. Kelly Byul Hahm and <hi>Yahoo</hi>! Angels <hi>Yahoo</hi>! Angles is a volunteer community group formed<sep />"
    result = search(query)
    assert_equal(1, result.hitcount)
    if is_streaming
      assert_equal(exp_body_streaming, result.hit[0].field['body'])
    else
      assert_equal(exp_body_indexed, result.hit[0].field['body'])
    end

    feed_and_wait_for_docs("site", 1, :file => selfdir+"feed2.json")
    query = "((yahoo OR ((y))) ) OR ((qterms:yahoo @@@) OR (qterms:y @@@)) OR ((weightedtags:yahoo @@@) OR (weightedtags:y @@@)) OR ((anchor:yahoo OR ((anchor:y))) ) OR ((keywords:yahoo OR ((keywords:y))) ) OR ((breadcrumb:yahoo OR ((breadcrumb:y))) ) OR ((title2:yahoo OR ((title2:y))) ) OR ((title3:yahoo OR ((title3:y))) ) OR ((catarr1:yahoo OR ((catarr1:y))) ) OR ((catarr4:yahoo OR ((catarr4:y))) ) OR ((uri:yahoo OR ((uri:y))) ) OR ((person:yahoo OR ((person:y))) )&type=adv"
    wait_for_hitcount(query, 1)
    exp_body = "TV <hi>Y</hi>! News RSS <hi>Y</hi>! News Alert All <hi>Yahoo</hi>! Trending Now McKayla"
    result = search(query)
    assert_equal(1, result.hitcount)
    assert(result.hit[0].field['body'].include? exp_body)


    feed_and_wait_for_docs("site", 3, :file => selfdir+"feed3.json")
    query = "cafe+menu&type=all"
    wait_for_hitcount(query, 2)
    exp_body_0_0 = "<hi>Café</hi> Surf's <hi>Café</hi> Print <hi>Menu</hi> Email a Friend"
    exp_body_0_1 = " Print <hi>Menu</hi> Print Details"
    exp_body_1_0 = "week s Tuesday Dinner <hi>Menu</hi>! This pilot program is currently scheduled"
    exp_body_1_1 = "Questions or comments? Reach us at <hi>cafe</hi>@yahoo-inc.com ."
    result = search(query)
    assert_equal(2, result.hitcount)
    assert(result.hit[0].field['body'].include? exp_body_0_0)
    assert(result.hit[0].field['body'].include? exp_body_0_1)
    assert(result.hit[1].field['body'].include? exp_body_1_0)
    assert(result.hit[1].field['body'].include? exp_body_1_1)
  end

  def teardown
    stop
  end

end
