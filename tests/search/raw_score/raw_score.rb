# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_search_test'

class RawScore < IndexedSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_raw_score
    add_bundle(selfdir + "ItemRawScoreTestSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.test.ItemRawScoreTestSearcher"))
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").search_chain(search_chain))
    start
    feed(:file => selfdir + "docs.xml")

    result = search("query=")
    assert(result.hit.size == 1)
    sf = result.hit[0].field["summaryfeatures"]
    puts "summaryfeatures for hit: '#{sf}'"
    json = sf
    assert_features({"queryTermCount" => 6}, json)
    assert_features({"rawScore(normal_features)" => 6}, json)
    assert_features({"rawScore(normal_features_fastsearch)" => 6}, json)

    assert_features({"itemRawScore(normal_foo)" => 1}, json)
    assert_features({"itemRawScore(normal_fastsearch_foo)" => 1}, json)

    assert_features({"itemRawScore(normal_bar)" => 2}, json)
    assert_features({"itemRawScore(normal_fastsearch_bar)" => 2}, json)

    assert_features({"itemRawScore(normal_baz)" => 3}, json)
    assert_features({"itemRawScore(normal_fastsearch_baz)" => 3}, json)

    vespa.search["search"].first.trigger_flush
    
    result = search("query=normal_features_fastsearch:baz")
    assert(result.hit.size == 1)
    sf = result.hit[0].field["summaryfeatures"]
    json = sf
    puts "summaryfeatures for hit: '#{sf}'"
    assert_features({"queryTermCount" => 7}, json)
    assert_features({"itemRawScore(normal_baz)" => 3}, json)
    assert_features({"itemRawScore(normal_fastsearch_baz)" => 3}, json)

    #Test using dotproduct items as part of RANK operator
    result = search("query=normal_features_fastsearch:baz&useRank=true")
    assert(result.hit.size == 1)
    sf = result.hit[0].field["summaryfeatures"]
    json = sf
    puts "summaryfeatures for hit: '#{sf}'"
    assert_features({"queryTermCount" => 7}, json)
    assert_features({"itemRawScore(normal_baz)" => 3}, json)
    assert_features({"itemRawScore(normal_fastsearch_baz)" => 3}, json)
  end

  def teardown
    stop
  end

end
