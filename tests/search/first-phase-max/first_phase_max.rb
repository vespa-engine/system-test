# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class FirstPhaseMax < IndexedOnlySearchTest

  def setup
    set_owner('johsol')
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 5, :file => selfdir + 'docs.json')
  end

  def test_first_phase_max
    # firstPhaseMax exposes the largest first-phase rank score computed on the node.
    # max(order) = 300, second-phase = order + firstPhaseMax = order + 300.
    result = search({'query' => 'sddocname:test', 'ranking' => 'default'})
    assert_equal(5, result.hitcount)
    assert_equal([600.0, 550.0, 500.0, 450.0, 400.0], extract_scores(result))
    assert_equal([300.0, 300.0, 300.0, 300.0, 300.0], extract_features(result, 'matchfeatures', 'firstPhaseMax'))
  end

  def test_dynamic_relative_threshold
    # Simulates a relative drop threshold: keep hits where first-phase score
    # is at least 70% of the per-node first-phase max, otherwise emit -1 so
    # rank-score-drop-limit drops them.
    # max(order) = 300, threshold = 0.7 * 300 = 210.
    # Only order >= 210 (i.e. 250, 300) survives. Score = order * 2.
    result = search({'query' => 'sddocname:test', 'ranking' => 'dynamic_threshold'})
    assert_equal(2, result.hitcount)
    assert_equal([600.0, 500.0], extract_scores(result))
    assert_equal([300.0, 300.0], extract_features(result, 'matchfeatures', 'firstPhaseMax'))
  end

  def extract_features(result, field, feature)
    features = []
    result.hit.each do |h|
      features.push(h.field[field][feature])
    end
    features
  end

  def extract_scores(result)
    scores = []
    result.hit.each do |h|
      scores.push(h.field['relevancy'])
    end
    scores
  end

end
