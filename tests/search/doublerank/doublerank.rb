# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class DoubleRank < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.cluster(
                        SearchCluster.new("doublerank1").
                        sd(selfdir + "doublerank.sd").
                        doc_type("doublerank", "doublerank.cluster==1")).
                      cluster(
                        SearchCluster.new("doublerank2").
                        sd(selfdir + "doublerank.sd").
                        doc_type("doublerank", "doublerank.cluster==2")))
    start
    feed_and_wait_for_docs("doublerank", 6, :file => selfdir + "doublerank.6.xml", :clusters => ["doublerank1", "doublerank2"])
  end

  def test_doublerank
    result =  search("/?query=cluster:1+cluster:2&type=any&hits=20&format=xml")
    assert result.hit[0].field["relevancy"] == "4.123123123123E12"
    assert result.hit[1].field["relevancy"] == "1000.0"
    assert result.hit[2].field["relevancy"].slice(0, 14) == "2.718281828459"
    assert result.hit[3].field["relevancy"] == "0.0"
    assert result.hit[4].field["relevancy"] == "-1000.0"
    assert result.hit[5].field["relevancy"] == "-4.123123123123E12"
  end

  def teardown
    stop
  end

end
