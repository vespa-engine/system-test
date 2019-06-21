# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class Bm25FeatureTest < SearchTest

  def setup
    set_owner("geirst")
  end

  def test_bm25_feature
    set_description("Test basic functionality of the bm25 rank feature")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start

    # Note: Average field length for these documents = 4 ((7 + 3 + 2) / 3).
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    assert_bm25_scores
    
    vespa.search["search"].first.trigger_flush
    assert_bm25_scores

    restart_proton("test", 3)
    assert_bm25_scores
  end

  def assert_bm25_scores
    assert_scores_for_query("content:a", [score(2, 3, idf(3)),
                                          score(3, 7, idf(3)),
                                          score(1, 2, idf(3))])

    assert_scores_for_query("content:b", [score(1, 3, idf(2)),
                                          score(1, 7, idf(2))])

    assert_scores_for_query("content:a+content:d", [score(1, 2, idf(3)) + score(1, 2, idf(2)),
                                                    score(3, 7, idf(3)) + score(1, 7, idf(2))])
  end

  def idf(matching_doc_count, total_doc_count = 3)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    Math.log(1 + ((total_doc_count - matching_doc_count + 0.5) / (matching_doc_count + 0.5)))
  end

  def score(num_occs, field_length, inverse_doc_freq, avg_field_length = 4)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    inverse_doc_freq * (num_occs * 2.2) / (num_occs + (1.2 * (0.25 + 0.75 * field_length / avg_field_length)))
  end

  def assert_scores_for_query(query, exp_scores)
    result = search(query)
    assert_hitcount(result, exp_scores.length)
    for i in 0...exp_scores.length do
      assert_relevancy(result, exp_scores[i], i)
    end
  end

  def teardown
    stop
  end

end
