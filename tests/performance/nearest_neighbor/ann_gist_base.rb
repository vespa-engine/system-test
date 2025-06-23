# Copyright Vespa.ai. All rights reserved.
# Private reason: Depends on pub/ data

require 'performance/nearest_neighbor/common_sift_gist_base'

class AnnGistBase < CommonSiftGistBase

  def initialize(*args)
    super(*args)
    @data_path = "gist-data/"
    @docs_300k = @data_path + "docs.300k.json"
    @docs_1k = @data_path + "docs.1k.json" # Used for development and testing
    @query_vectors = @data_path + "query_vectors.100.txt"
    @query_vectors_small = @data_path + "query_vectors.10.txt" # Used for development and testing

    # To re-generate test data:
    # ./create_gist_test_data.sh
  end

  def run_gist_test(sd_dir)
    deploy_app(create_app(sd_dir, 0.3))
    start
    @container = vespa.container.values.first

    feed_and_benchmark(@docs_300k, "300k-docs")

    query_and_benchmark(BRUTE_FORCE, 10, 0, 0, 1)

    prepare_queries_for_recall

    run_target_hits_10_tests

    [1, 10, 50, 90, 95, 99].each do |filter_percent|
      query_and_benchmark(HNSW, 100, 0, filter_percent, 1)
      query_and_benchmark(BRUTE_FORCE, 100, 0, filter_percent, 1)
    end
  end

end
