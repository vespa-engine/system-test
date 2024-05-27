# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class FirstPhaseRank < IndexedOnlySearchTest

  def setup
    set_owner('toregge')
  end

  def test_first_phase_rank
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 5, :file => selfdir + 'docs.json')

    # All documents from first phase are reranked
    result = search({'query' => 'sddocname:test'})
    assert_equal(5, result.hitcount)
    assert_equal([300.0, 250.0, 200.0, 150.0, 100.0], extract_features(result, 'matchfeatures', 'firstPhase'))
    assert_equal([1.0, 2.0, 3.0, 4.0, 5.0], extract_features(result, 'matchfeatures', 'firstPhaseRank'))
    assert_equal([Float::MAX, Float::MAX, Float::MAX, Float::MAX, Float::MAX], extract_features(result, 'summaryfeatures', 'firstPhaseRank'))

    # 3 documents from first phase are reranked
    result = search({'query' => 'sddocname:test', 'ranking.rerankCount' => 3})
    assert_equal(5, result.hitcount)
    assert_equal([1.0, 2.0, 3.0, Float::MAX, Float::MAX], extract_features(result, 'matchfeatures', 'firstPhaseRank'))
  end

  def extract_features(result, field, feature)
    features = []
    result.hit.each do |h|
      features.push(h.field[field][feature])
    end
    features
  end

  def teardown
    stop
  end

end
