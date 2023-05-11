# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class AttributeMatchFeatures < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def create_query(query)
    return query
  end

  def test_attributematch
    set_description("Test the attributeMatch feature")
    deploy_app(SearchApp.new.sd(selfdir + "attributematch.sd"))
    start
    feed_and_wait_for_docs("attributematch", 2, :file => selfdir + "attributematch.xml")
    assert_hitcount(create_query("query=sddocname:attributematch"), 2)

    # single value attribute
    assert_feature_x(1, 1,      1,      1, "a", "a:a")
    assert_feature_x(2, 1,      1,      1, "a", "a:a+a:a")
    assert_feature_x(0, 0,      0,      0, "a", "b:b")
    assert_feature_x(1, 0.5,    0.5,    1, "a", "a:a+a:x")
    assert_feature_x(1, 0.3333, 0.3333, 1, "a", "a:a+a:x+a:x")
    # check that other query terms do not interfere
    assert_feature_x(1, 1,      1,      1, "a", "a:a+b:b")
    assert_feature_x(1, 1,      1,      1, "a", "a:a+b:x")


    # array attribute
    assert_feature_x(1, 0.9625, 1,      0.25, "b", "b:b")
    assert_feature_x(2, 0.975,  1,      0.5,  "b", "b:b+b:c")
    assert_feature_x(3, 0.9875, 1,      0.75, "b", "b:b+b:c+b:d")
    assert_feature_x(4, 1,      1,      1,    "b", "b:b+b:b+b:c+b:d")
    assert_feature_x(5, 1,      1,      1,    "b", "b:b+b:b+b:b+b:c+b:d")
    assert_feature_x(0, 0,      0,      0,    "b", "a:a")
    assert_feature_x(1, 0.4813, 0.5,    0.25, "b", "b:b+b:x")
    assert_feature_x(1, 0.3208, 0.3333, 0.25, "b", "b:b+b:x+b:x")
    # check that other query terms do not interfere
    assert_feature_x(1, 0.9625, 1, 0.25, "b", "b:b+a:a")
    assert_feature_x(1, 0.9625, 1, 0.25, "b", "b:b+a:x")
    # use non-default fieldCompletenessImportance=0.5
    assert_feature_x(1, 0.625, 1, 0.25, "b", "b:b&ranking=rpb")


    # weighted set attribute
    assert_feature_x(1, 0.955,  1,      0.1, "c", "c:c")
    assert_feature_x(2, 0.965,  1,      0.3, "c", "c:c+c:d")
    assert_feature_x(3, 1,      1,      1,   "c", "c:c+c:d+c:e")
    assert_feature_x(4, 1,      1,      1,   "c", "c:c+c:c+c:d+c:e")
    assert_feature_x(0, 0,      0,      0,   "c", "a:a")
    assert_feature_x(1, 0.4775, 0.5,    0.1, "c", "c:c+c:x")
    assert_feature_x(1, 0.3183, 0.3333, 0.1, "c", "c:c+c:x+c:x")
    # check that other query terms do not interfere
    assert_feature_x(1, 0.955, 1, 0.1, "c", "c:c+a:a")
    assert_feature_x(1, 0.955, 1, 0.1, "c", "c:c+a:x")

    # testing of weights
    assert_feature_y(10, 10, 0.0391, 0.0391, "c:c") # 10/256, 10*100/(256*100)
    assert_feature_y(20, 20, 0.0781, 0.0781, "c:d") # 20/256, 20*100/(256*100)
    assert_feature_y(70, 70, 0.2734, 0.2734, "c:e") # 70/256, 70*100/(256*100)
    assert_feature_y(30, 15, 0.0586, 0.0586, "c:c+c:d") # 30/(256*2), 10*100+20*100/(256*200)
    assert_feature_y(90, 45, 0.1758, 0.1758, "c:d+c:e") # 90/(256*2), 20*100+70*100/(256*200)
    assert_feature_y(30, 15, 0.0586, 0.0742, "c:c+c:d!900") # 30/(256*2), 10*100+20*900/(256*1000)
    assert_feature_y(90, 45, 0.1758, 0.2539, "c:d+c:e!900") # 90/(256*2), 20*100+70*100/(256*200)
    # use non-default maxWeight=200
    assert_feature_y(10, 10, 0.05, 0.05, "c:c&ranking=rpc") # 10/200, 10*100/(200*100)

    # negative total weight
    assert_feature_x(1,   0.95, 1, 0, "c", "c:c",     1)
    assert_feature_x(2,   0.95, 1, 0, "c", "c:c+c:d", 1)
    assert_feature_y(-10, -10,  0, 0, "c:c",     1)
    assert_feature_y(-30, -15,  0, 0, "c:c+c:d", 1)
  end

  def assert_feature_x(matches, completeness, queryCompleteness, fieldCompleteness, field, query, docid=0)
    expected = {"matches" => matches, "completeness" => completeness, "" => completeness, \
                "queryCompleteness" => queryCompleteness, "fieldCompleteness" => fieldCompleteness}
    assert_feature(expected, field, query, docid)
  end

  def assert_feature_y(totalWeight, averageWeight, normalizedWeight, normalizedWeightedWeight, query, docid=0)
    expected = {"totalWeight" => totalWeight, "averageWeight" => averageWeight, \
                "normalizedWeight" => normalizedWeight, "normalizedWeightedWeight" => normalizedWeightedWeight}
    assert_feature(expected, "c", query, docid)
  end

  def assert_feature(expected, field, query, docid=0)
    query = create_query("query=" + query + "&parallel&nocache&type=any")
    result = search(query)
    result.sort_results_by("documentid")
    pexp = {}
    expected.each do |name,score|
      if (name == "")
        pexp["attributeMatch(#{field})"] = score
      else
        pexp["attributeMatch(#{field}).#{name}"] = score
      end
    end
    puts "#{result.hit[docid].field['summaryfeatures']}"
    assert_features(pexp, result.hit[docid].field['summaryfeatures'], 1e-4)
  end

  def teardown
    stop
  end

end
