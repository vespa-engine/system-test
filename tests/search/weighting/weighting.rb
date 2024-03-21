# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class Weighting < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Rank using weighting of terms")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.json")
  end

  def q(tw = nil)
    q1 = '/search/?yql=select+%2A+from+sources+%2A+where+%28'
    q2 = 'title+contains+%22jackson%22'
    q3 = '+OR+artist+contains+%22jackson%22'
    q4 = '%29+limit+12%3B&format=xml'
    if tw
      q2 = 'title+contains+%28%5B%7B%22weight%22%3A+' + tw.to_s + '%7D%5D%22jackson%22%29'
    end
    query = q1 + q2 + q3 + q4
    return query
  end

  def test_weighting
    puts "Check that 100 is the default weighting"
    assert_queries_match(q(100), q())

    puts "Reduce the weight of a term by 50%, check that hits are the same, but ordering different"
    assert_queries_match(q(50), q(), 'name="surl"', true)
    assert_not_queries_match(q(50), q(), 'name="surl"', false)

    puts "Increase the weight of a term by 150%, check that hits are the same, but ordering different"
    assert_queries_match(q(250), q(), 'name="surl"', true)
    assert_not_queries_match(q(250), q(), 'name="surl"', false)

    puts "Check that !(bang) equals a weight of 150%"
    assert_queries_match("query=title:jackson!+artist:jackson&type=any&sorting=-[rank]-year&hits=21",
			 "query=title:jackson!150+artist:jackson&type=any&sorting=-[rank]-year&hits=21")

    puts "Check that !!(double bang) equals a weight of 200%"
    assert_queries_match("query=title:jackson!!+artist:jackson&type=any&sorting=-[rank]-year&hits=21",
			 "query=title:jackson!200+artist:jackson&type=any&sorting=-[rank]-year&hits=21")
  end

  def test_weighting_cap
    puts "Check that there are no longer any capping of termweight (bug #2723263)"
    assert_termweight(100)
    assert_termweight(1000)
    assert_termweight(10000)
    assert_termweight(100000)
    assert_termweight(100000)
    assert_termweight(1000000)
    assert_termweight(10000000)
    assert_termweight(100000000)
    assert_termweight(500000000)
  end

  def assert_termweight(weight)
    query = "query=jackson!#{weight}&rankfeatures"
    exp = { "term(0).weight" => weight }
    assert_features(exp, search(query).hit[0].field["rankfeatures"])
  end

  def teardown
    stop
  end

end
