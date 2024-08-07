# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class SecondPhaseRankScoreDropLimit < IndexedOnlySearchTest

  def setup
    set_owner('toregge')
  end

  def test_second_phase_rank_score_drop_limit
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 7, :file => selfdir + 'docs.json')

    query = {'yql' => 'select * from sources * where true',
            'ranking.rerankCount' => 2}

    # 2 documents from first phase are reranked
    result = search(query)
    assert_equal([[11,14.0],[12,13.0],[10,12.0],[5,11.0],[16,10.0],[15,9.0],[14,5.0]], extract_ids_and_scores(result))

    # 2 documents from first phase are reranked
    # Drop is among rescaled scores from first phase ranking
    result = search(query.merge({'ranking' => 'second-phase-rank-score-drop-limit-9'}))
    assert_equal([[11,14.0],[12,13.0],[10,12.0],[5,11.0],[16,10.0]], extract_ids_and_scores(result))

    # 2 documents from first phase are reranked
    # Drop is among reranked hits in second phase
    result = search(query.merge({'ranking' => 'second-phase-rank-score-drop-limit-13'}))
    assert_equal([[11,14.0]], extract_ids_and_scores(result))

    # 2 documents from first phase are reranked
    # Drop is among reranked hits in second phase
    # second phase rank score drop limit is passed as a query parameter
    result = search(query.merge({'ranking.secondPhase.rankScoreDropLimit' => '13.0'}))
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
