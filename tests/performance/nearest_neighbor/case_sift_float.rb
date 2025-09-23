# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/ann_sift_base'

class AnnSiftPerfTest < AnnSiftBase

  def setup
    super
    set_owner("boeker")
  end

  def test_sift_data_set
    set_description("Test performance and recall using nearestNeighbor operator (hnsw vs brute force) over the 1M SIFT (128 dim) dataset")
    run_sift_test("sift_test", true)
  end


end
