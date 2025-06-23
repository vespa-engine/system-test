# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# Private reason: Depends on pub/ data

require 'performance/nearest_neighbor/ann_sift_base'

class AnnSiftBFloat16PerfTest < AnnSiftBase

  def setup
    super
    set_owner("geirst")
  end

  def test_sift_data_set_bfloat16
    set_description("Test performance and recall using nearestNeighbor operator (hnsw vs brute force) over the 1M SIFT (128 dim) dataset using bfloat16")
    run_sift_test("sift_test_bfloat16")
  end

  def teardown
    super
  end

end
