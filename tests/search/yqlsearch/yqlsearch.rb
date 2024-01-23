# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
    query += '&renderer.json.jsonMaps=true'
    query += '&renderer.json.jsonWsets=true'
    fields = ['title', 'name', 'score', 'documentid']
    assert_result(query, expected_file, nil, fields)
  end

  def check_yql_hits(yql, hitcount)
    query = "/search/?query=#{yql}&type=yql&format=json"
    assert_hitcount(query, hitcount)
    query = "/search/?yql=#{yql}&format=json"
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

    assert_hitcount("query=select+ignoredfield+from+ignoredsource+where+default+contains+%22country%22&type=yql", 1)
    assert_hitcount("query=select+ignoredfield+from+ignoredsource+where+score+%3D+2&type=yql", 1)
    assert_hitcount("query=select+ignoredfield+from+ignoredsource+where+default+contains+%28%5B%7B%22distance%22%3A1%7D%5Dnear%28%22modern%22%2C%22electric%22%29%29&type=yql&tracelevel=1", 1)

    assert_result("query=select+ignoredfield+from+ignoredsource+where+wand%28name%2C%7B%22electric%22%3A10%2C%22modern%22%3A20%7D%29&ranking=weightedSet&type=yql&tracelevel=1", selfdir + "result.json", nil, [ 'relevancy' ])

    # if RANK does not work, try OR:
  # yql = 'select * from sources * where (title contains ({significance:0.75}"blues")) OR (title contains ({significance:1.0}"country")) | all(group(score)each(output(count())))'
    yql = 'select * from sources * where rank(title contains ({significance:0.75}"blues"), title contains ({significance:1.0}"country")) | all(group(score)each(output(count())))'
    query = "/search/?yql=#{CGI::escape(yql)}"
    assert_result_matches_wset_order_normalized(query, selfdir + "group-result.json")
  end

  def teardown
    stop
  end

end
