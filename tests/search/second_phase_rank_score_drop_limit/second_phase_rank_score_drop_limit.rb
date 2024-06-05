# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class SecondPhaseRankScoreDropLimit < IndexedOnlySearchTest

  def setup
    set_owner('toregge')
  end

  def test_second_phase_rank_score_drop_limit
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 7, :file => selfdir + 'docs.json')

    query = {'yql' => 'select * from sources * where true'}
    # All documents from first phase are reranked
    result = search(query)
    assert_equal([[10,1201.0],[5,1101.0],[16,1001.0],[15,901.0],[14,501.0],[11,14.0],[12,13.0]], extract_ids_and_scores(result))

    # 2 documents from first phase are reranked
    result = search(query.merge({'ranking.rerankCount' => 2}))
    assert_equal([[11,14.0],[12,13.0],[10,12.0],[5,11.0],[16,10.0],[15,9.0],[14,5.0]], extract_ids_and_scores(result))

    # 2 documents from first phase are reranked
    # second phase rank score drop limit is 9.0
    result = search(query.merge({'ranking.rerankCount' => 2, 'ranking' => 'second-phase-rank-score-drop-limit-9'}))
    assert_equal([[11,14.0],[12,13.0],[10,12.0],[5,11.0],[16,10.0]], extract_ids_and_scores(result))

    # Track score of 10 best hits from first phase
    # 2 documents from first phare reranked
    # second phase rank score drop limit is 9.0
    # 1 match thread
    # Ask for 4 hits
    result = search(query.merge({'ranking.keepRankCount' => 10, 'ranking.rerankCount' => 2, 'ranking' => 'second-phase-rank-score-drop-limit-9', 'ranking.matching.numThreadsPerSearch' => 1, 'hits' => 4}))
    assert_equal([[11,14.0],[12,13.0],[10,12.0],[5,11.0]], extract_ids_and_scores(result))
    assert_equal(5, result.hitcount)

    # Track score of 4 best hits from first phase
    # 2 documents from first phare reranked
    # second phase rank score drop limit is 9.0
    # 1 match thread
    # Ask for 4 hits
    result = search(query.merge({'ranking.keepRankCount' => 4, 'ranking.rerankCount' => 2, 'ranking' => 'second-phase-rank-score-drop-limit-9', 'ranking.matching.numThreadsPerSearch' => 1, 'hits' => 4}))
    assert_equal([[11,14.0],[12,13.0],[10,12.0],[5,11.0]], extract_ids_and_scores(result))
    assert_equal(4, result.hitcount)

    # 2 documents from first phase are reranked
    # second phase rank score drop limit is 9.0
    result = search(query.merge({'ranking.rerankCount' => 2, 'ranking' => 'second-phase-rank-score-drop-limit-13'}))
    assert_equal([[11,14.0]], extract_ids_and_scores(result))

end

  def extract_ids_and_scores(result)
    ids_and_scores = []
    result.hit.each do |h|
      id = h.field['documentid'].sub('id:test:test::','').to_i
      ids_and_scores.push([id, h.field['relevancy'].to_f])
    end
    ids_and_scores
  end

  def teardown
    stop
  end

end
