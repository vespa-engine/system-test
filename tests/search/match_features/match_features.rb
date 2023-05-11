# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'set'
require 'indexed_streaming_search_test'

class MatchFeatures < IndexedStreamingSearchTest

  def setup
    set_owner('arnej')
    @seen = Set.new
  end

  def s(query)
    query += '&format=json'
    query += '&ranking.features.query(mix)={{x:x1,y:0}:1,{x:x2,y:1}:1}'
    query += '&ranking.features.query(vec)=[2.5,7.5]'
    query += '&streaming.selection=true'
    query += '&ranking=withmf'
    #puts "Query: #{query}"
    result = search(query)
    #puts "Result: #{result}"
    #puts "Raw result: #{result.xmldata}"
    return result
  end

  def test_match_features
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd').
               search_dir(selfdir + 'search'))
    start
    feed_and_wait_for_docs('test', 5, :file => selfdir + 'docs.json')

    result = s('query=foo+foo')
    assert(result.hit.size == 3)
    assert_mf_hit(result, 0, 300)
    assert_mf_hit(result, 1, 200)
    assert_mf_hit(result, 2, 100)

    result = s('query=bar')
    assert(result.hit.size == 2)
    assert_mf_hit(result, 0, 250)
    assert_mf_hit(result, 1, 150)

    puts "Native rank scores: #{@seen}"
    assert_equal(5, @seen.size)
  end

  def assert_mf_hit(result, hit, attr_value)
    assert_equal(attr_value, result.hit[hit].field['order'].to_i)
    mf = result.hit[hit].field['matchfeatures']
    #puts "match-features for hit #{hit}: '#{mf}'"
    assert_equal(2.0, mf['value(2)'])
    assert_equal(attr_value, mf['attribute(order)'])
    assert_equal('tensor(x{},y[2])', mf['attribute(mixed)']['type'])
    assert_equal('tensor(x{})', mf['rankingExpression(score_per_x)']['type'])
    assert_equal('tensor(y[2])', mf['query(vec)']['type'])
    native = mf['nativeFieldMatch']
    assert(native > 0)
    @seen.add(native)
  end

  def teardown
    stop
  end

end
