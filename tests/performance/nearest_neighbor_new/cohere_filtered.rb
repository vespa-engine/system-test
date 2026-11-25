# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_filtered_base'

class AnnCohereFilteredPerfTest < CohereFilteredBase

  def setup
    super
    set_owner("boeker")
  end

  def test_cohere_filtered
    num_documents = 2_000_000 # The first vectors of cohere/cohere-data/docs_*.fvecs are used
    num_queries_for_benchmark = 1000
    num_queries_for_recall = 100 # The first queries used for benchmarking
    hit_ratios = [0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001]
    settings = [
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.01}
    ]

    # Smaller values that can be used for development and testing
    #num_documents = 10_000
    #num_queries_for_recall = 10

    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration})
    set_label_format("%{name}-th%{target_hits}-%{correlation}-hr%{hit_ratio}-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) with filters that are not, positively, and negatively correlated with the query vector " +
                    "over #{num_documents} Cohere Wikipedia embeddings (1024 dim)")
    run_filtered_test(schema: "filtered",
                      num_documents: num_documents,
                      num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall,
                      hit_ratios: hit_ratios,
                      settings: settings)
  end

  def test_cohere_filtered_quantized
    num_documents = 2_000_000 # The first vectors of cohere/cohere-data/docs_*.fvecs are used
    num_queries_for_benchmark = 1000
    num_queries_for_recall = 100 # The first queries used for benchmarking
    hit_ratios = [0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001]
    settings = [
      # Always use HNSW, without the filter-first heuristic
      {:name => "hnsw", :quantization_bits => 4, :target_hits => 100, # The quantization bits as in the schema
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00}
    ]

    # Smaller values that can be used for development and testing
    #num_documents = 10_000
    #num_queries_for_recall = 10

    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold})
    set_label_format("%{name}-q%{quantization_bits}-th%{target_hits}-%{correlation}-hr%{hit_ratio}-at%{approximate_threshold}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) over 4-bit quantized vectors with filters that are not, positively, and negatively correlated with the query vector " +
                    "over #{num_documents} Cohere Wikipedia embeddings (1024 dim)")
    run_filtered_test(schema: "filtered_quantized",
                      num_documents: num_documents,
                      num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall,
                      hit_ratios: hit_ratios,
                      settings: settings,
                      nnr: {"exactField" => "embedding_f32"}) # Full-precision vectors as the exact ground truth
  end

end
