# Copyright Vespa.ai. All rights reserved.
# Private reason: Depends on pub/ data

require 'performance/nearest_neighbor/ann_gist_base'

class AnnGistPerfTest < AnnGistBase

  def setup
    super
    set_owner("geirst")
  end

  def test_gist_data_set
    set_description("Test performance and recall using nearestNeighbor operator (hnsw vs brute force) over the 1M (300k fed) GIST (960 dim) dataset")
    run_gist_test("gist_test")
  end

  def teardown
    super
  end

end
