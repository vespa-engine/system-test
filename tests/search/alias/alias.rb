# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Alias < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
    set_description("Test the alias names as configured, for selecting indexes")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def can_share_configservers?(method_name=nil)
    true
  end

  def comp(q, f, re)
    assert_result(q, selfdir+f, 'title', [ 'title' ])
  end

  def test_alias
    feed_and_wait_for_docs("music", 19, :file => selfdir+"music.19.xml")

    regexp = /"title"|total-hit-count/
    puts "Query: Search using no explicit index"
    comp('query=hate&type=all', "defaultalias.result.json", regexp)

    puts "Query: Search using explicit default index"
    comp('query=default:hate&type=all', "defaultalias.result.json", regexp)

    puts "Query: Search using alias 'testalias1' for index"
    comp('query=testalias1:hate&type=all', "defaultalias.result.json", regexp)

    puts "Query: Search using a nonexisting combination for index"
    assert_hitcount('query=song.song:hate&type=all', 0)

    puts "Query: Search using explicit alias 'song' for index (default)"
    comp('query=song:hate&type=all', "songalias.result.json", regexp)

    puts "Query: Search using 'default-index=song'"
    comp('query=hate&default-index=song&type=all', "songalias.result.json", regexp)

    puts "Query: Search using 'default-index=year' on query not having that token in that index"
    assert_hitcount('query=hate&default-index=uri&type=all', 0)

    regexp = /total-hit-count|"documentid"/
    puts "Query: Search using a index other than default"
    comp('query=hate%20year:2000&type=all', "yearalias.result.json", regexp)

    puts "Query: Search using explicit alias 'testalias2' for index"
    comp('query=hate%20testalias2:2000&type=all', "yearalias.result.json", regexp)

    puts "Query: Search using 'default-index=year'"
    comp('query=default:hate+2000&default-index=year&type=all', "yearalias.result.json", regexp)

    puts "Query: Search using 'default-index=testalias2'"
    comp('query=testalias1:hate+2000&default-index=testalias2&type=all', "yearalias.result.json", regexp)

    puts "Query: Search using an attribute"
    comp('query=hate+weight:1700000&type=all',                   "weight.result.json", regexp)

    puts "Query: Search using alias for an attribute"
    comp('query=hate+testalias3:1700000&type=all',               "weight.result.json", regexp)

    puts "Query: Search using an attribute via default-index"
    comp('query=1700000&default-index=weight&type=all',     "weight.result.json", regexp)

    puts "Query: Search using alias for an attribute via default-index"
    comp('query=1700000&default-index=testalias3&type=all', "weight.result.json", regexp)

    # URL indexing doesn't work the same way in streaming
    if ! is_streaming
      puts "Query: Search using alias for a part of a URL"
      assert_hitcount('query=site:www.bigband.com&type=all', 1)
    end

  end

  def teardown
    stop
  end

end
