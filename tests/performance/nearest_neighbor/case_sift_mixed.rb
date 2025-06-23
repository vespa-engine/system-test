# Copyright Vespa.ai. All rights reserved.
# Private reason: Depends on pub/ data

require 'performance/nearest_neighbor/ann_sift_base'

class AnnSiftMixedPerfTest < AnnSiftBase

  def setup
    super
    set_owner("geirst")
  end

  def test_sift_data_set_mixed
    set_description("Test performance and recall using nearestNeighbor operator (hnsw vs brute force) over the 1M SIFT (128 dim) dataset using a mixed tensor")
    run_sift_test("sift_test_mixed", false, true)
  end

  def teardown
    super
  end

end
