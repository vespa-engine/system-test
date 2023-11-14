# -*- coding: utf-8 -*-
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Bug5707026 < IndexedSearchTest

  def setup
    set_owner("geirst")
    set_description("Test for bug 5707026, unmatched <hi> in dynamic summary (juniper) field")
  end

  def test_bug5707026
    deploy_app(SearchApp.new.sd(selfdir+"site.sd"))
    start
    feed_and_wait_for_docs("site", 1, :file => selfdir+"feed.xml")

    query = "(yahoo ) OR (qterms:yahoo @@@) OR (weightedtags:yahoo @@@) OR (anchor:yahoo ) OR (keywords:yahoo ) OR (breadcrumb:yahoo ) OR (title2:yahoo ) OR (title3:yahoo ) OR (catarr1:yahoo ) OR (uri:yahoo ) OR (person:yahoo ) AND&type=adv"
    wait_for_hitcount(query, 1)
    exp_body = "<hi>Yahoo</hi>! Korea is lucky to have<sep />Choi, a project manager on the <hi>Yahoo</hi>! Custom Brand<sep />of a volunteer organization outside <hi>Yahoo</hi>!. He told me that altruistic<sep />"
    result = search(query)
    assert_equal(1, result.hitcount)
    assert_equal(exp_body, result.hit[0].field['body'])
  end

  def test_bug5707026_2
    deploy_app(SearchApp.new.sd(selfdir+"site.sd"))
    start
    feed_and_wait_for_docs("site", 1, :file => selfdir+"feed2.xml")

    query = "((yahoo OR ((y))) ) OR ((qterms:yahoo @@@) OR (qterms:y @@@)) OR ((weightedtags:yahoo @@@) OR (weightedtags:y @@@)) OR ((anchor:yahoo OR ((anchor:y))) ) OR ((keywords:yahoo OR ((keywords:y))) ) OR ((breadcrumb:yahoo OR ((breadcrumb:y))) ) OR ((title2:yahoo OR ((title2:y))) ) OR ((title3:yahoo OR ((title3:y))) ) OR ((catarr1:yahoo OR ((catarr1:y))) ) OR ((catarr4:yahoo OR ((catarr4:y))) ) OR ((uri:yahoo OR ((uri:y))) ) OR ((person:yahoo OR ((person:y))) )&type=adv"
    wait_for_hitcount(query, 1)
    exp_body = "<sep />TV <hi>Y</hi>! News RSS <hi>Y</hi>! News Alert All <hi>Yahoo</hi>! Trending Now McKayla<sep />"
    result = search(query)
    assert_equal(1, result.hitcount)
    assert_equal(exp_body, result.hit[0].field['body'])
  end

  def test_bug5707026_3
    deploy_app(SearchApp.new.sd(selfdir+"site.sd"))
    start
    feed_and_wait_for_docs("site", 3, :file => selfdir+"feed3.xml")

    query = "cafe+menu&type=all"
    wait_for_hitcount(query, 2)
    exp_body_0 = "<sep /><hi>Café</hi> Surf's <hi>Café</hi> Print <hi>Menu</hi> Email a Friend<sep /> Print <hi>Menu</hi> Print Details<sep />"
    exp_body_1 = "<sep />week s Tuesday Dinner <hi>Menu</hi>! This pilot program is currently scheduled<sep />Questions or comments? Reach us at <hi>cafe</hi>@yahoo-inc.com ."
    result = search(query)
    assert_equal(2, result.hitcount)
    assert_equal(exp_body_0, result.hit[0].field['body'])
    assert_equal(exp_body_1, result.hit[1].field['body'])
  end

  def teardown
    stop
  end

end
