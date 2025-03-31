# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SelectJsonQuery < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
    set_description("Test that we can POST Json payload with a 'select' query")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_search
    start

    feed(:file => SEARCH_DATA + "music.10.json")
    select_json_string = "{ 'select': { 'where': { 'contains': ['default', 'country'] } } }"
    result = post_query(select_json_string)
    assert_equal(1, result.hit.length)
  end

  def post_query(query)
    vespa.container.values.first.post_search("/search/", query, 0, {'Content-Type' => 'application/json'})
  end

  def teardown
    stop
  end

end
