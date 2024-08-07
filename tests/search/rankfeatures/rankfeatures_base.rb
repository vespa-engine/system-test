# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'


module RankFeaturesBase

  def setup
    set_owner("geirst")
  end

  def assert_rankfeatures(expected, result, hit)
    puts "---- check rankfeatures for hit #{hit} ----"
    assert_features(expected, result)
  end

  def assert_empty_rankfeatures(result)
    result.hit.each_index do |i|
      assert_equal(nil, result.hit[i].field["rankfeatures"], "At hit #{i}: ")
    end
  end

  def assert_nonexisting_rankfeatures(result)
    result.hit.each_index do |i|
      assert(!result.hit[i].field.has_key?("rankfeatures"), "Did not expect 'rankfeatures' xml tag at hit #{i}")
    end
  end

  def assert_dump(expected, query)
    query = "query=" + query + "&rankfeatures&streaming.userid=1"
    result = search(query)
    expected = expected.sort
    actual = result.hit[0].field["rankfeatures"].keys.sort

    assert_equal(expected.size, actual.size)
    expected.each_index do |i|
      assert_equal(expected[i], actual[i])
    end
  end

  def teardown
    stop
  end

end
