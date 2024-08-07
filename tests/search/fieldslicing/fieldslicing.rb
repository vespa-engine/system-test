# Copyright Vespa.ai. All rights reserved.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class FieldSlicing < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_slicing
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")
    assert_hitcount("query=a", 1)

    # GROUP: alone

    # query: a
    result = search("query=alone:a&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    assert_features({"fieldInfo(alone).len" => 3}, features)
    assert_features({"fieldInfo(alone).first" => 0}, features)
    assert_features({"fieldInfo(alone).last" => 0}, features)
    assert_features({"fieldInfo(alone).cnt" => 1}, features)

    # query: b
    result = search("query=alone:b&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    assert_features({"fieldInfo(alone).len" => 3}, features)
    assert_features({"fieldInfo(alone).first" => 1}, features)
    assert_features({"fieldInfo(alone).last" => 1}, features)
    assert_features({"fieldInfo(alone).cnt" => 1}, features)

    # query: c
    result = search("query=alone:c&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    assert_features({"fieldInfo(alone).len" => 3}, features)
    assert_features({"fieldInfo(alone).first" => 2}, features)
    assert_features({"fieldInfo(alone).last" => 2}, features)
    assert_features({"fieldInfo(alone).cnt" => 1}, features)

    # GROUP: default

    # query: a
    result = search("query=a&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    assert_features({"fieldInfo(default1).len" => 6}, features)
    assert_features({"fieldInfo(default1).first" => 0}, features)
    assert_features({"fieldInfo(default1).last" => 5}, features)
    assert_features({"fieldInfo(default1).cnt" => 2}, features)
    assert_features({"fieldInfo(default2).len" => 12}, features)
    assert_features({"fieldInfo(default2).first" => 0}, features)
    assert_features({"fieldInfo(default2).last" => 11}, features)
    assert_features({"fieldInfo(default2).cnt" => 4}, features)
    assert_features({"fieldInfo(default3).len" => 18}, features)
    assert_features({"fieldInfo(default3).first" => 0}, features)
    assert_features({"fieldInfo(default3).last" => 17}, features)
    assert_features({"fieldInfo(default3).cnt" => 6}, features)

    # query: b
    result = search("query=b&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    assert_features({"fieldInfo(default1).len" => 6}, features)
    assert_features({"fieldInfo(default1).first" => 1}, features)
    assert_features({"fieldInfo(default1).last" => 4}, features)
    assert_features({"fieldInfo(default1).cnt" => 2}, features)
    assert_features({"fieldInfo(default2).len" => 12}, features)
    assert_features({"fieldInfo(default2).first" => 2}, features)
    assert_features({"fieldInfo(default2).last" => 9}, features)
    assert_features({"fieldInfo(default2).cnt" => 4}, features)
    assert_features({"fieldInfo(default3).len" => 18}, features)
    assert_features({"fieldInfo(default3).first" => 3}, features)
    assert_features({"fieldInfo(default3).last" => 14}, features)
    assert_features({"fieldInfo(default3).cnt" => 6}, features)

    # query: c
    result = search("query=c&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    assert_features({"fieldInfo(default1).len" => 6}, features)
    assert_features({"fieldInfo(default1).first" => 2}, features)
    assert_features({"fieldInfo(default1).last" => 3}, features)
    assert_features({"fieldInfo(default1).cnt" => 2}, features)
    assert_features({"fieldInfo(default2).len" => 12}, features)
    assert_features({"fieldInfo(default2).first" => 4}, features)
    assert_features({"fieldInfo(default2).last" => 7}, features)
    assert_features({"fieldInfo(default2).cnt" => 4}, features)
    assert_features({"fieldInfo(default3).len" => 18}, features)
    assert_features({"fieldInfo(default3).first" => 6}, features)
    assert_features({"fieldInfo(default3).last" => 11}, features)
    assert_features({"fieldInfo(default3).cnt" => 6}, features)

    # PHRASE

    # query: "a a b"
    result = search("query=%22a+a+b%22&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    expected = {
      "fieldInfo(default1).len"   => 1000000,
      "fieldInfo(default1).first" => 1000000,
      "fieldInfo(default1).last"  => 1000000,
      "fieldInfo(default1).cnt"   =>       0,
      "fieldInfo(default2).len"   =>      12,
      "fieldInfo(default2).first" =>       0,
      "fieldInfo(default2).last"  =>       0,
      "fieldInfo(default2).cnt"   =>       1,
      "fieldInfo(default3).len"   =>      18,
      "fieldInfo(default3).first" =>       1,
      "fieldInfo(default3).last"  =>       1,
      "fieldInfo(default3).cnt"   =>       1
    }
    assert_features(expected, features, 1e-4)
  end

  def test_slicing_in_both_phases
    set_owner("geirst")
    set_description("Test that field slicing is working both during first and second phase ranking")
    deploy_app(SearchApp.new.sd(selfdir + "slice.sd"))
    start
    feed_and_wait_for_docs("slice", 2, :file => selfdir + "slice.json")
    wait_for_hitcount("query=a+b", 2)

    a = search("query=a+b&ranking=slice-in-second&nocache")
    b = search("query=a+b&ranking=slice-in-both&nocache")
    assert_equal(a.hit[0].field["relevancy"].to_i, b.hit[0].field["relevancy"].to_i)
    assert_equal(a.hit[1].field["documentid"],     b.hit[1].field["documentid"])
  end

  def teardown
    stop
  end

end
