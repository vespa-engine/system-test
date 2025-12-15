# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/common_sift_gist_base'

class AnnSiftBase < CommonSiftGistBase

  def initialize(*args)
    super(*args)
    @data_path = "sift-data/"
    @base_fvecs = @data_path + "sift_base.fvecs"
    @query_fvecs = @data_path + "sift_query.fvecs"
    @dimensions = 128

    @num_queries_for_benchmark = 1000
  end

  def run_sift_test(sd_dir, test_threads_per_search = false, mixed_tensor = false)
    deploy_app(create_app(sd_dir, 0.3, (test_threads_per_search ? 16 : 1)))
    start

    num_queries_for_recall = 100
    num_documents = 1_000_000
    num_updates = 200_000
    filter_values = [1, 10, 50, 90, 95, 99]

    # Smaller values that can be used for development and testing
    #num_queries_for_recall = 10
    #num_documents = 20_000
    #num_updates = 10_000

    compile_generators
    generate_queries_for_recall(num_queries_for_recall)
    feed_and_benchmark(num_documents, "1M-docs", {:filter_values => filter_values, :mixed_tensor => mixed_tensor})

    query_and_benchmark(BRUTE_FORCE, 10, 0)

    run_target_hits_10_tests

    run_target_hits_100_tests

    filter_values.each do |filter_percent|
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
        query_and_benchmark(HNSW, 100, 0, {:filter_percent => 10, :threads_per_search => threads})
        # Now with filter-first heuristic enabled
        query_and_benchmark(HNSW, 100, 0, {:filter_percent => 10, :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.3, :threads_per_search => threads})
      end
    end

    # This feed is updating documents [500000-700000) with the same values as documents [0-200000).
    # This ensures that the vector values actually changes,
    # and avoids the optimization that skips changing the HNSW graphs when vectors are unchanged.
    feed_and_benchmark(num_updates, "1M-updates", {:start_with_docid => num_documents / 2, :filter_values => filter_values, :mixed_tensor => mixed_tensor})
  end

  def run_sift_removal_test(sd_dir)
    deploy_app(create_app(sd_dir, 0.3, 1))
    start

    num_queries_for_recall = 100
    documents_to_benchmark_at = 500_000
    documents_in_total = 1_000_000

    # Smaller values that can be used for development and testing
    #num_queries_for_recall = 10
    #documents_to_benchmark_at = 5_000
    #documents_in_total = 10_000

    compile_generators
    generate_queries_for_recall(num_queries_for_recall)
    run_removal_test(documents_to_benchmark_at, documents_in_total, "1M-docs")
  end

end
