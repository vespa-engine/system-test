# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'
require 'resultset'
require 'cgi'

class YqlSearch < IndexedStreamingSearchTest

  # This is in search because this test needs to be expanded with
  # "funky stuff" which needs to be tested in a search context.

  def setup
    set_owner("arnej")
    set_description("Test searching with YQL+")
  end

  def test_yqlsearch
    deploy_app(SearchApp.new.
               cluster_name("basicsearch").
               sd(selfdir+"music.sd"))
    start_feed_and_check
  end

  def start_feed_and_check
    start
    feed_and_check
  end

  def assert_result_matches_wset_order_normalized(query, expected_file)
    query = query.merge({'renderer.json.jsonMaps' => 'true',
                         'renderer.json.jsonWsets' => 'true'})
    fields = ['title', 'name', 'score', 'documentid']
    assert_result(query, expected_file, nil, fields)
  end

  def check_yql_hits(yql, hitcount)
    query = { 'query' => yql, 'type' => 'yql', 'format' => 'json' }
    assert_hitcount(query, hitcount)
    query = { 'yql' => yql, 'format' => 'json' }
    assert_hitcount(query, hitcount)
  end

  def feed_and_check
    feed(:file => selfdir+"music.3.json", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 3)

    check_yql_hits('select * from sources * where false', 0)
    check_yql_hits('select * from sources * where default contains "country"', 1)
    check_yql_hits('select * from sources * where (default contains "country") or false', 1)

    check_yql_hits('select * from sources * where true;', 3)
    check_yql_hits('select * from sources * where true AND !(default contains "country")', 2)

    assert_hitcount({ 'query' => 'select ignoredfield from ignoredsource where default contains "country"', 'type' => 'yql'}, 1)
    assert_hitcount({ 'query' => 'select ignoredfield from ignoredsource where score = 2', 'type' => 'yql' }, 1)
    assert_hitcount({ 'query' => 'select ignoredfield from ignoredsource where default contains ([{"distance":1}]near("modern","electric"))', 'type' => 'yql', 'tracelevel' => '1'}, 1)

    assert_result({ 'query' => 'select ignoredfield from ignoredsource where wand(name,{"electric":10,"modern":20})', 'ranking' => 'weightedSet', 'type' => 'yql', 'tracelevel' => 1}, selfdir + "result.json", nil, [ 'relevancy' ])

    # if RANK does not work, try OR:
  # yql = 'select * from sources * where (title contains ({significance:0.75}"blues")) OR (title contains ({significance:1.0}"country")) | all(group(score)each(output(count())))'
    yql = 'select * from sources * where rank(title contains ({significance:0.75}"blues"), title contains ({significance:1.0}"country")) | all(group(score)each(output(count())))'
    query = { 'yql' => yql }
    assert_result_matches_wset_order_normalized(query, selfdir + "group-result.json")
  end

  def teardown
    stop
  end

end
