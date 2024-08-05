# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class IgnoreResult < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    deploy_app(SearchApp.new.sd("#{selfdir}/music.sd").
                      routingtable(RoutingTable.new.no_verify.
                                   add(Route.new("myroute", "foo")).
                                   add(Hop.new("foo", "bar").ignore).
                                   add(Hop.new("bar", "[AND:mysession]")).
                                   add(Hop.new("myhop", "mysession").ignore)))
    start
  end

  def test_ignoreResult
    feed_and_wait_for_docs("music", 1, :file => "#{selfdir}/metallica_feed.json", :timeout => 240, :trace => 9, :route => "\"[AND:default myroute myhop ?myservice]\"")
    assert_result("query=metallica", "#{selfdir}/metallica_result.json")
  end

  def teardown
    stop
  end

end
