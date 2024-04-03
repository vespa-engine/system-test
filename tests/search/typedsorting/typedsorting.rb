# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class TypedSorting < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
    deploy_app(SearchApp.new.cluster(
                        SearchCluster.new("music1").sd(selfdir + "music.sd").
                        doc_type("music", "music.mid==2")).
                      cluster(
                        SearchCluster.new("music2").sd(selfdir + "music.sd").
                        doc_type("music", "music.mid==3")))
    start
  end

  def compare(query, file, field=nil)
    fname = selfdir+file+".result"
    puts "Check if #{query} matches #{file}"
    assert_field(query,            fname, field, false)
    assert_field(query,            fname, field, false)
    assert_field(query+"&nocache", fname, field, false)
    assert_field(query,            fname, field, false)
  end

  def test_typedsorting
    feed_and_wait_for_docs("music", 20, :file => selfdir + "titlesorting.20.json", :cluster => "music1")

    compare("query=categories:blues&sorting=%2Btitle&hits=3",            "A3")
    compare("query=categories:blues&sorting=%2Btitle_lowercase&hits=3",  "B3")
    compare("query=categories:blues&sorting=%2Blikeint&hits=3",          "C3")
    compare("query=categories:blues&sorting=%2Bisint&hits=3",            "D3")

    compare("query=categories:blues&sorting=%2Btitle&hits=20",           "A20")
    compare("query=categories:blues&sorting=%2Btitle_lowercase&hits=20", "B20")
    compare("query=categories:blues&sorting=%2Blikeint&hits=20",         "C20")
    compare("query=categories:blues&sorting=%2Bisint&hits=20",           "D20")

  end

  def teardown
    stop
  end

end
