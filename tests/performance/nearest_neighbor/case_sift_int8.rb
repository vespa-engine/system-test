# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/ann_sift_base'

class AnnSiftPerfTest < AnnSiftBase

  def setup
    super
    set_owner("boeker")
  end

  def set_int8
    @data_path = "sift-data-int8/"
    @base_fvecs = @data_path + "sift_base.i8vecs"
    @query_fvecs = @data_path + "sift_query.i8vecs"
    @file_data_type = "int8"
  end

  def test_sift_data_set
    set_description("Test performance and recall using nearestNeighbor operator (hnsw vs brute force) over the 1M SIFT (128 dim) dataset cast to int8")
    set_int8
    run_sift_test("sift_test_int8", true)
  end

  def test_geolocation_sift_data_set
    set_description("Test performance and recall using nearestNeighbor combined with geoLocation operator (hnsw vs brute force) over the 1M SIFT (128 dim) dataset cast to int8")
    set_int8
    run_sift_geolocation_test("sift_test_int8")
  end

  def test_removal_sift_data_set
    set_description("Test recall using nearestNeighbor operator (hnsw) over the 1M SIFT (128 dim) dataset before and after removal of many documents cast to int8")
    set_int8
    run_sift_removal_test("sift_test_int8")
  end

end
