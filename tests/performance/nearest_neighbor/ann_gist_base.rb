# Copyright Vespa.ai. All rights reserved.

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

    query_and_benchmark(BRUTE_FORCE, 10, 0)

    prepare_queries_for_recall

    run_target_hits_10_tests

    [1, 10, 50, 90, 95, 99].each do |filter_percent|
      query_and_benchmark(BRUTE_FORCE, 100, 0, filter_percent)
      # Standard HNSW
      query_and_benchmark(HNSW, 100, 0, filter_percent)
      # Now with filter-first heuristic enabled
      query_and_benchmark(HNSW, 100, 0, filter_percent, 0.00, 0.40, 0.01)

      # Recall for standard HNSW
      calc_recall_for_queries(100, 0, filter_percent)
      # Recall for filter-first heuristic
      calc_recall_for_queries(100, 0, filter_percent, 0.00, 0.40, 0.01)
    end
  end

end
