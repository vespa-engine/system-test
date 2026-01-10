# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/common_sift_gist_base'

class AnnGistBase < CommonSiftGistBase

  def initialize(*args)
    super(*args)
    @data_path = "gist-data/"
    #@base_fvecs = @data_path + "gist_base.fvecs" # Original file with 1M vectors
    @base_fvecs = @data_path + "gist_base_300k.fvecs" # Smaller file that only contains the first 300k vectors
    @query_fvecs = @data_path + "gist_query.fvecs"
    @dimensions = 960

    @num_queries_for_benchmark = 1000
  end

  def run_gist_test(sd_dir)
    deploy_app(create_app(sd_dir, 0.3))
    start

    num_queries_for_recall = 100
    num_documents = 300_000
    filter_values = [1, 10, 50, 90, 95, 99]

    # Smaller values that can be used for development and testing
    #num_queries_for_recall = 10
    #num_documents = 1_000

    compile_generators
    generate_vectors_for_recall(num_queries_for_recall)
    feed_and_benchmark(num_documents, "300k-docs", {:filter_values => filter_values})

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

    num_queries_for_recall = 100
    documents_to_benchmark_at = 150_000
    documents_in_total = 300_000

    # Smaller values that can be used for development and testing
    #num_queries_for_recall = 10
    #documents_to_benchmark_at = 5_000
    #documents_in_total = 10_000

    compile_generators
    generate_vectors_for_recall(num_queries_for_recall)
    run_removal_test(documents_to_benchmark_at, documents_in_total, "300k-docs")
  end

end
