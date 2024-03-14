# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_only_search_test'
require 'search/fieldmatchfeatures/fieldmatchfeatures_base'


class FieldMatchFeaturesIndexed < IndexedOnlySearchTest

  include FieldMatchFeaturesBase

  def test_field_match_literal_boost
    set_description("Test the fieldMatch feature together with literal boost")
    deploy_app(SearchApp.new.sd(selfdir + "fmliteral.sd"))
    start
    feed_and_wait_for_docs("fmliteral", 2, :file => selfdir + "fmliteral.json")

    assert_literal_best(0, "a:book")
    assert_literal_best(1, "a:booked")

    assert_literal_matches(1, "a:book",   0)
    assert_literal_matches(0, "a:book",   1)
    assert_literal_matches(0, "a:booked", 0)
    assert_literal_matches(1, "a:booked", 1)
  end

  def test_field_match_filter
    set_description("Test the fieldMatch feature together with filter index")
    deploy_app(SearchApp.new.sd(selfdir + "fmfilter.sd"))
    start
    feed_and_wait_for_docs("fmfilter", 1, :file => selfdir + "fmfilter.json")

    assert_fmfilter(0,     1,     1, 1, "a:a")
    assert_fmfilter(0,     1,     1, 2, "a:a+a:b")
    assert_fmfilter(0,   0.5,   0.5, 1, "a:a+a:x")
    assert_fmfilter(0, 0.333, 0.333, 1, "a:a+a:x+a:x")
    assert_fmfilter(0,     0,     0, 0, "sddocname:fmfilter")

    # change the weight
    assert_fmfilter(0,  0.5,  0.25, 1, "a:a!100+a:x!300")
    assert_fmfilter(0,    1,  0.25, 1, "a:a!100+b:x!300")
    assert_fmfilter(0,  0.5, 0.143, 1, "a:a!100+a:x!300+b:x!300")
  end

end
