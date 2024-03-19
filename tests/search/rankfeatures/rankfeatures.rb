# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_only_search_test'
require 'search/rankfeatures/rankfeatures_base'


class RankFeatures < IndexedOnlySearchTest

  include RankFeaturesBase

  def test_basic
    set_description("Test basic rank features")
    deploy_app(SearchApp.new.sd(selfdir + "basic.sd"))
    start
    feed_and_wait_for_docs("basic", 3, :file => selfdir + "basic.json")

    result = search("query=title:alpha&rankfeatures&skipnormalizing")
    last_score = Float::MAX
    for i in [0,1,2]
      assert_equal("id:basic:basic::#{i}", result.hit[i].field["documentid"], "At hit #{i}: ")
      score = result.hit[i].field["relevancy"].to_f
      assert(score > 0.0, "Expected rank score > 0.0 at hit #{i}")
      assert(score < last_score, "Expected rank score #{score} < #{last_score} at hit #{i}")
      last_score = score
      rf_result = result.hit[i].field["rankfeatures"]
      rf_expected = {}
      rf_expected["nativeRank"] = score
      rf_expected["firstPhase"] = score
      assert_rankfeatures(rf_expected, rf_result, i)
    end

    assert_empty_rankfeatures(search("query=title:alpha&skipnormalizing"))
    assert_nonexisting_rankfeatures(search("query=title:alpha&skipnormalizing"))
  end

  def test_dump
    set_description("Test that the expected rank features are dumped using proton")
    deploy_app(SearchApp.new.sd(selfdir + "dump.sd"))
    start

    feed_and_wait_for_docs("dump", 1, :file => selfdir + "dump.json")

    # The rankfeatures dumped should be in accordance with:
    # http://vespa/4.0/documentation/search/reference/rank-features.html
    expected = []
    File.open(selfdir + "dump.txt", "r").each do |line|
      expected.push(line.strip)
    end

    assert_dump(expected, "a:a+b:b+c:c")

    extra = ["term(5).connectedness", "term(5).significance", "term(5).weight"]
    assert_dump(expected + extra, "a:a+b:b+c:c&ranking=extra")
    assert_dump(extra,            "a:a+b:b+c:c&ranking=ignore")
  end

end
