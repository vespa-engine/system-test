# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/common_sift_gist_base'

class AnnSiftBase < CommonSiftGistBase

  def initialize(*args)
    super(*args)
    @data_path = "sift-data/"
    @docs_1M = @data_path + "docs.1M.json"
    @docs_mixed_1M = @data_path + "docs.mixed.1M.json"
    @docs_10k = @data_path + "docs.10k.json" # Used for development and testing
    # These are updating documents [500000-700000) with the same values as documents [0-200000).
    # This ensures that the vector values actually changes,
    # and avoids the optimization that skips changing the HNSW graphs when vectors are unchanged.
    @updates_200k = @data_path + "updates.200k.json"
    @updates_mixed_200k = @data_path + "updates.mixed.200k.json"
    @updates_10k = @data_path + "updates.10k.json" # Used for development and testing
    @query_vectors = @data_path + "query_vectors.100.txt"
    @query_vectors_small = @data_path + "query_vectors.10.txt" # Used for development and testing

    # To re-generate test data:
    # ./create_sift_test_data.sh
  end

  def run_sift_test(sd_dir, test_threads_per_search = false, mixed_tensor = false)
    deploy_app(create_app(sd_dir, 0.3, (test_threads_per_search ? 16 : 1)))
    start
    @container = vespa.container.values.first

    feed_and_benchmark((mixed_tensor ? @docs_mixed_1M : @docs_1M), "1M-docs")

    query_and_benchmark(BRUTE_FORCE, 10, 0)

    prepare_queries_for_recall

    run_target_hits_10_tests

    run_target_hits_100_tests

    [1, 10, 50, 90, 95, 99].each do |filter_percent|
      query_and_benchmark(BRUTE_FORCE, 100, 0, {:filter_percent => filter_percent})
      # Standard HNSW
      query_and_benchmark(HNSW, 100, 0, {:filter_percent => filter_percent})
      # Now with filter-first heuristic enabled
      query_and_benchmark(HNSW, 100, 0, {:filter_percent => filter_percent, :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.3})
      # Increased exploration
      query_and_benchmark(HNSW, 100, 0, {:filter_percent => filter_percent, :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.35})

      # Recall for standard HNSW
      calc_recall_for_queries(100, 0, {:filter_percent => filter_percent})
      # Recall for filter-first heuristic
      calc_recall_for_queries(100, 0, {:filter_percent => filter_percent, :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.3})
      # Increased exploration
      calc_recall_for_queries(100, 0, {:filter_percent => filter_percent, :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.35})
    end

    if test_threads_per_search
      [1, 2, 4, 8, 16].each do |threads|
        # Standard HNSW
        query_and_benchmark(HNSW, 100, 0, {:filter_percent => 10, :threads => threads})
        # Now with filter-first heuristic enabled
        query_and_benchmark(HNSW, 100, 0, {:filter_percent => 10, :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.3, :threads => threads})
      end
    end

    feed_and_benchmark((mixed_tensor ? @updates_mixed_200k : @updates_200k), "1M-updates")
  end

  def run_sift_removal_test(sd_dir)
    deploy_app(create_app(sd_dir, 0.3, 1))
    start
    @container = vespa.container.values.first

    prepare_queries_for_recall

    run_removal_test(@docs_1M, "1M-docs", 500000, 1000000)
  end

end
