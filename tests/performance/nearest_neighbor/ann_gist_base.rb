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
    @dimensions = 960
    @base_fvecs = "gist_base.fvecs"
    @query_fvecs = "gist_query.fvecs"
    @num_queries = 1000
    @num_queries_for_recall = 100
  end

  def run_gist_test(sd_dir)
    deploy_app(create_app(sd_dir, 0.3))
    start
    compile_generators
    download_and_prepare_queries

    filter_values = [1, 10, 50, 90, 95, 99]
    download_feed_and_benchmark_documents(300_000, filter_values, "300k-docs")

    query_and_benchmark(BRUTE_FORCE, 10, 0)

    run_target_hits_10_tests

    filter_values.each do |filter_percent|
      query_and_benchmark(BRUTE_FORCE, 100, 0, {:filter_percent => filter_percent})
      # Standard HNSW
      query_and_benchmark(HNSW, 100, 0, {:filter_percent => filter_percent})
      # Now with filter-first heuristic enabled
      query_and_benchmark(HNSW, 100, 0, {:filter_percent => filter_percent, :approximate_threshold => 0.00, :filter_first_threshold => 0.40, :filter_first_exploration => 0.3})

      # Recall for standard HNSW
      calc_recall_for_queries(100, 0, {:filter_percent => filter_percent})
      # Recall for filter-first heuristic
      calc_recall_for_queries(100, 0, {:filter_percent => filter_percent, :approximate_threshold => 0.00, :filter_first_threshold => 0.40, :filter_first_exploration => 0.3})
    end
  end

  def run_gist_removal_test(sd_dir)
    deploy_app(create_app(sd_dir, 0.3))
    start
    compile_generators
    download_and_prepare_queries

    run_removal_test(150_000, 300_000, "300k-docs")
  end

end
