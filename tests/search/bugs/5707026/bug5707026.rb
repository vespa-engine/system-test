# -*- coding: utf-8 -*-
# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
    exp_body = "<hi>Yahoo</hi>! Korea is<sep />are not just dedicated to <hi>Yahoo</hi>!, but to the betterment<sep /> Hahm and <hi>Yahoo</hi>! Angels<sep />"
    assert_field_value(query, "body", exp_body)
  end

  def test_bug5707026_2
    deploy_app(SearchApp.new.sd(selfdir+"site.sd"))
    start
    feed_and_wait_for_docs("site", 1, :file => selfdir+"feed2.xml")

    query = "((yahoo OR ((y))) ) OR ((qterms:yahoo @@@) OR (qterms:y @@@)) OR ((weightedtags:yahoo @@@) OR (weightedtags:y @@@)) OR ((anchor:yahoo OR ((anchor:y))) ) OR ((keywords:yahoo OR ((keywords:y))) ) OR ((breadcrumb:yahoo OR ((breadcrumb:y))) ) OR ((title2:yahoo OR ((title2:y))) ) OR ((title3:yahoo OR ((title3:y))) ) OR ((catarr1:yahoo OR ((catarr1:y))) ) OR ((catarr4:yahoo OR ((catarr4:y))) ) OR ((uri:yahoo OR ((uri:y))) ) OR ((person:yahoo OR ((person:y))) )&type=adv"
    wait_for_hitcount(query, 1)
    exp_body = "<sep />! News RSS <hi>Y</hi>! News Alert All <hi>Yahoo</hi>! Trending Now<sep />"
    assert_field_value(query, "body", exp_body)
  end

  def test_bug5707026_3
    deploy_app(SearchApp.new.sd(selfdir+"site.sd"))
    start
    feed_and_wait_for_docs("site", 3, :file => selfdir+"feed3.xml")

    query = "cafe+menu"
    wait_for_hitcount(query, 2)
    exp_body_0 = "<sep /><hi>Café</hi> Surf's <hi>Café</hi> Print <hi>Menu</hi> Email a Friend<sep /> Print <hi>Menu</hi> Print Details<sep />"
    exp_body_1 = "<sep />week s Tuesday Dinner <hi>Menu</hi>! This pilot program is currently scheduled<sep />Questions or comments? Reach us at <hi>cafe</hi>@yahoo-inc.com ."
    assert_field_value(query, "body", exp_body_0, 0)
    assert_field_value(query, "body", exp_body_1, 1)
  end

  def teardown
    stop
  end

end
