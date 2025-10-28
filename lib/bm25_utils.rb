# Copyright Vespa.ai. All rights reserved.

# Bm25 related functions used by Bm25FeatureTest and SameElementOperator

module Bm25Utils
  def assert_elementwise_bm25_feature(feature_name, exp_cells, features)
    feature = features[feature_name]
    puts "assert_elementwise_bm25_feature: feature=#{feature}"
    assert(feature.is_a?(Hash))
    assert(feature.include?('type') && feature.include?('cells') && feature.keys.size == 2)
    assert_equal("tensor(x{})", feature['type'])
    cells = feature['cells']
    assert(cells.is_a?(Hash))
    assert_equal(cells.keys.sort, exp_cells.keys.sort)
    cells.each do |k, v|
      exp_v = exp_cells[k]
      assert_approx(exp_v, v, 1e-6, "Value for cell #{k} differs")
    end
  end

  def nonzero_cells(scores)
    scores.each_with_index.map { |score, idx| [ idx.to_s, score ] }.delete_if { |x| x[1] == 0 }.to_h
  end
end
