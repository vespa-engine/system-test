# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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

    assert_bar([250, 150], nil)
    # Verify that you also get match features if you are sorting.
    assert_bar([250, 150], "sortspec=-order")
    # TODO There is something odd when running streaming.
    assert_bar([150, 250], "sortspec=+order") if ! is_streaming

    puts "Native rank scores: #{@seen}"
    assert_equal(5, @seen.size)
  end

  def assert_bar(order, extra)
    q = 'query=bar'
    q =  q + "&" + extra if extra
    result = s(q)
    assert(result.hit.size == 2)
    assert_mf_hit(result, 0, order[0])
    assert_mf_hit(result, 1, order[1])
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
