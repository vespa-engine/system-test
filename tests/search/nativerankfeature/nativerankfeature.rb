# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class NativeRankFeature < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_native_field_match
    set_description("Test the nativeFieldMatch feature")
    deploy_app(SearchApp.new.sd(selfdir+"fieldmatch.sd"))
    start
    feed_and_wait_for_docs("fieldmatch", 2, :file => selfdir + "fieldmatch.xml")

    # query=a
    # doc 0
    # f1: firstocc = 0 (200), numocc = 4 (80)
    # f2: firstocc = 4 (60),  numocc = 1 (10)
    # doc 1
    # f1: firstocc = 5 (100), numocc = 1 (20)
    # f2: firstocc = 5 (50),  numocc = 1 (10)
    # hits in both f1 and f2
    assert_native_field_match(140,  "query=f1:a", "tables", 0) # (200 + 80) * 0.5
    assert_native_field_match(60,   "query=f1:a", "tables", 1) # (100 + 20) * 0.5
    assert_native_field_match(35,   "query=f2:a", "tables", 0) # (60 + 10) * 0.5
    assert_native_field_match(30,   "query=f2:a", "tables", 1) # (50 + 10) * 0.5
    assert_native_field_match(87.5, "query=a", "tables", 0) # (140 + 35) * 0.5
    assert_native_field_match(45,   "query=a", "tables", 1) # (60 + 30) * 0.5

    # hit in only f1
    assert_native_field_match(30,    "query=f1:b", "tables", 0) # (40 + 20) * 0.5
    assert_native_field_match(15,    "query=b",    "tables", 0) # (30 + 0) * 0.5
    # posocc for a in f2 is valid -> contribution is 35
    assert_native_field_match(51.25, "query=a+b",  "tables", 0) # ((140 + 35) * 0.5 + (30 + 0) * 0.5) * 0.5

    # different field weights
    assert_native_field_match(175, "query=a", "fieldweight", 0) # (200 * 300 + 100 * 100) * (1 / 400)

    # phrase query
    assert_native_field_match(55, "query=\"a x\"", "tables", 0) # ((180 + 40) * 0.5 + 0) * 0.5
    assert_native_field_match(60, "query=\"x a\"", "tables", 0) # ((140 + 20) * 0.5 + (70 + 10) * 0.5) * 0.5
  end

  def assert_native_field_match(score, query, ranking, hit)
    query = query + "&ranking=" + ranking
    query = query + "&rankproperty.vespa.term.1.significance=1&rankproperty.vespa.term.2.significance=1"
    assert_relevancy(query, score, hit)
  end


  def test_native_rank
    set_description("Test the nativeRank feature")
    deploy_app(SearchApp.new.sd(selfdir+"nativerank.sd"))
    start
    feed_and_wait_for_docs("nativerank", 11, :file => selfdir + "nativerank.xml")
    run_native_rank_test

    if !is_streaming
      # attribute tests
      assert_native_rank("query=f4:a")
      assert_native_rank("query=f4:a", "only-attribute-match")
      assert_native_rank("query=a+b+f4:a", "only-attribute-match")
    end
  end

  def run_native_rank_test
    wait_for_hitcount("query=sddocname:nativerank", 11)

    # 1 term
    assert_native_rank("query=a")
    assert_native_rank("query=a", "only-field-match")

    # 2 terms
    assert_native_rank("query=a+b")
    assert_native_rank("query=a+b", "only-field-match")
    assert_native_rank("query=a+b", "only-proximity")
    assert_native_rank("query=f1:a+f1:b")
    assert_native_rank("query=f1:a+f1:b", "only-field-match")
    assert_native_rank("query=f2:a+f2:b")
    assert_native_rank("query=f2:a+f2:b", "only-field-match")
    assert_native_rank("query=f3:a+f3:b")
    assert_native_rank("query=f3:a+f3:b", "only-proximity")

    # 3 terms
    assert_native_rank("query=a+b+f4:a")
    assert_native_rank("query=a+b+f4:a", "only-field-match")
    assert_native_rank("query=a+b+f4:a", "only-proximity")

    # zero field weights
    query = "query=a+b+f4:a&ranking=zero-weight"
    assert_relevancy(query, 0.0, 0)
    assert_relevancy(query, 0.0, 1)
    assert_relevancy(query, 0.0, 2)

    # or query
    assert_field("query=f1:first+f1:second&type=any&ranking=identity", selfdir + "ortest.result", "documentid")
  end

  def assert_native_rank(query, ranking = "default")
    query = query + "&ranking=" + ranking
    result = search(query)
    # the documents should be in this order
    assert_equal("id:nativerank:nativerank:n=1:0", result.hit[0].field["documentid"])
    assert_equal("id:nativerank:nativerank:n=1:1", result.hit[1].field["documentid"])
    assert_equal("id:nativerank:nativerank:n=1:2", result.hit[2].field["documentid"])
    r1 = result.hit[0].field["relevancy"].to_f
    r2 = result.hit[1].field["relevancy"].to_f
    r3 = result.hit[2].field["relevancy"].to_f
    assert(((r1 > r2) and (r2 > r3)), "Expected r1 (#{r1}) > r2 (#{r2}) > r3 (#{r3})")
  end


  def test_explicit_native_rank
    set_description("Test the nativeRank feature when explicit specifying which fields to include in the score calculation")
    deploy_app(SearchApp.new.sd(selfdir+"expnr.sd"))
    start
    feed_and_wait_for_docs("expnr", 1, :file => selfdir + "expnr.xml")
    run_explicit_native_rank_test

    if !is_streaming
      # default nativeRank
      assert_expnr(get_basic(0, 0,   0,  0), "query=f3:a")
      assert_expnr(get_basic(0, 0,   0,  0), "query=f3:a+f3:b")

      # only f3
      assert_expnr(get_explicit(0, 0, nil, 0, "f3"), "query=f3:a",      "only-f3")
      assert_expnr(get_explicit(0, 0, nil, 0, "f3"), "query=f3:a+f3:b", "only-f3")

      # only f4
    else
      # rank:filter only works for indexed search (test cases with f3 different).
      # nativeAttributeMatch only works for indexed search (test cases with f4 and f5 different, behaves as index fields).

      # default nativeRank
      assert_expnr(get_basic(800,   0, 0, 400), "query=f3:a")
      assert_expnr(get_basic(800, 800, 0, 600), "query=f3:a+f3:b")

      # only f3 (rank:filter only works for indexed search)
      assert_expnr(get_explicit(800,   0, nil, 400, "f3"), "query=f3:a",      "only-f3")
      assert_expnr(get_explicit(800, 800, nil, 600, "f3"), "query=f3:a+f3:b", "only-f3")
    end
  end

  def run_explicit_native_rank_test
    # default nativeRank
    assert_expnr(get_basic(300,   0, 0, 150), "query=a")
    assert_expnr(get_basic(300, 300, 0, 225), "query=a+b")
    assert_expnr(get_basic(0, 0, 300, 75), "query=f4:a+f5:a")

    # only f1
    assert_expnr(get_explicit(200,   0, nil, 100, "f1"), "query=a",         "only-f1")
    assert_expnr(get_explicit(200, 200, nil, 150, "f1"), "query=a+b",       "only-f1")
    assert_expnr(get_explicit(  0,   0, nil,   0, "f1"), "query=f2:a",      "only-f1")
    assert_expnr(get_explicit(  0,   0, nil,   0, "f1"), "query=f2:a+f2:b", "only-f1")
    assert_expnr(get_explicit(  0,   0, nil,   0, "f1"), "query=f4:a+f5:a", "only-f1")

    # only f3
    assert_expnr(get_explicit(0, 0, nil, 0, "f3"), "query=a",         "only-f3")
    assert_expnr(get_explicit(0, 0, nil, 0, "f3"), "query=a+b",       "only-f3")
    assert_expnr(get_explicit(0, 0, nil, 0, "f3"), "query=f4:a+f5:a", "only-f3")

    # only f4
    assert_expnr(get_explicit(0, 0, 0, 0, "f4"), "query=a",         "only-f4")
    assert_expnr(get_explicit(0, 0, 0, 0, "f4"), "query=a+b",       "only-f4")
    assert_expnr(get_explicit(0, 0, 200, 50, "f4"), "query=f4:a+f5:a", "only-f4")
  end

  def get_basic(nfm, np, nam, nr)
    return {"nativeFieldMatch" => nfm, "nativeProximity" => np, "nativeAttributeMatch" => nam, "nativeRank" => nr}
  end

  def get_explicit(nfm, np, nam, nr, f)
    if nam != nil
      return {"nativeFieldMatch(#{f})" => nfm, "nativeProximity(#{f})" => np, "nativeAttributeMatch(#{f})" => nam, "nativeRank(#{f})" => nr}
    else
      return {"nativeFieldMatch(#{f})" => nfm, "nativeProximity(#{f})" => np, "nativeRank(#{f})" => nr}
    end
  end

  def assert_expnr(expected, query, ranking = "default")
    query = query + "&ranking=" + ranking
    puts "assert_expnr: #{query}"
    result = search(query)
    assert_features(expected, result.hit[0].field['summaryfeatures'], 1e-4)
  end


  def teardown
    stop
  end

end
