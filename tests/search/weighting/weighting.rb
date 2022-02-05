# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_search_test'

class Weighting < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Rank using weighting of terms")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
  end

  def test_weighting

    puts "Check that 100 is the default weighting"
    assert_queries_match("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%28%5B%7B%22weight%22%3A%20100%7D%5D%22jackson%22%29%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			 "query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22jackson%22%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql")

    puts "Reduce the weight of a term by 50%, check that hits are the same, but ordering different"
    assert_queries_match("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%28%5B%7B%22weight%22%3A%2050%7D%5D%22jackson%22%29%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			 "query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22jackson%22%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			 "name=\"surl\"", true)

    assert_not_queries_match("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%28%5B%7B%22weight%22%3A%2050%7D%5D%22jackson%22%29%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			     "query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22jackson%22%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			     "name=\"surl\"", false)

    puts "Increase the weight of a term by 10%, check that hits are the same, but ordering different"
    assert_queries_match("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%28%5B%7B%22weight%22%3A%20110%7D%5D%22jackson%22%29%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			 "query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22jackson%22%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			 "name=\"surl\"", true)

    assert_not_queries_match("query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%28%5B%7B%22weight%22%3A%2050%7D%5D%22jackson%22%29%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			     "query=select%20%2A%20from%20sources%20%2A%20where%20%28title%20contains%20%22jackson%22%20OR%20artist%20contains%20%22jackson%22%29%20limit%2021%3B&type=yql",
			     "name=\"surl\"", false)

    puts "Check that !(bang) equals a weight of 150%"
    assert_queries_match("query=title:jackson!+artist:jackson&type=any&hits=21",
			 "query=title:jackson!150+artist:jackson&type=any&hits=21")

    puts "Check that !!(double bang) equals a weight of 200%"
    assert_queries_match("query=title:jackson!!+artist:jackson&type=any&hits=21",
			 "query=title:jackson!200+artist:jackson&type=any&hits=21")

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
