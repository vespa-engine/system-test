# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_search_test'

class CombiningFeatures < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_match
    set_description("Test the match feature")
    deploy_app(SearchApp.new.sd(selfdir + "match.sd"))
    start
    feed_and_wait_for_docs("match", 2, :file => selfdir + "match.xml")
    assert_hitcount("query=sddocname:match", 2)

    assert_feature({"match" => 1.0, "match.totalWeight" => 200.0}, "a:a")
    assert_feature({"match" => 1.0, "match.totalWeight" => 300.0}, "b:b")
    assert_feature({"match" => 1.0, "match.totalWeight" => 400.0}, "c:c")
    assert_feature({"match" => 1.0, "match.totalWeight" => 100.0}, "d:d")

    assert_feature({"match" => 1.0, "match.totalWeight" => 1000.0}, "a:a+b:b+c:c+d:d")
    assert_feature({"match" => 1.0, "match.totalWeight" => 500.0},  "a:a+b:b")
    assert_feature({"match" => 1.0, "match.totalWeight" => 700.0},  "b:b+c:c")
    assert_feature({"match" => 1.0, "match.totalWeight" => 500.0},  "c:c+d:d")

    # cases where not all terms match
    assert_feature({"match" => 1.0, "match.totalWeight" => 200.0}, "a:a+b:x")
    assert_feature({"match" => 1.0, "match.totalWeight" => 300.0}, "b:b+c:x")
    assert_feature({"match" => 1.0, "match.totalWeight" => 400.0}, "c:c+d:x")
    assert_feature({"match" => 1.0, "match.totalWeight" => 100.0}, "d:d+a:x")

    # cases where match != 1.0 and where weights are tested
    # (0.3571? * 200 + 0.5 * 400) / 600
    assert_feature({"match" => 0.4597, "match.totalWeight" => 600.0}, "a:a+a:x+c:c+c:x")

    # search in the default index
    assert_feature({"match" => 1.0, "match.totalWeight" => 500.0}, "e")
    assert_feature({"match" => 1.0, "match.totalWeight" => 900.0}, "e+c:e")
    # (0.3571? * 200 + 0.3571? * 300 + 1 * 400) / 900
    assert_feature({"match" => 0.6551, "match.totalWeight" => 900.0}, "e+x+c:e")

    # check that the boost values are retrieved
    rb = {"match.weight.a" => 200.0, "match.weight.b" => 300.0, \
          "match.weight.c" => 400.0, "match.weight.d" => 100.0}
    assert_feature(rb, "a:a")
    assert_feature(rb, "b:b")
    assert_feature(rb, "c:c")
    assert_feature(rb, "d:d")
    assert_feature(rb, "a:a+b:b+c:c+d:d")
  end


  def assert_feature(expected, query)
    query = "query=" + query + "&parallel&nocache&type=any"
    result = search(query)
    assert_features(expected, result.hit[0].field['summaryfeatures'], 1e-4)
  end

  def teardown
    stop
  end

end
