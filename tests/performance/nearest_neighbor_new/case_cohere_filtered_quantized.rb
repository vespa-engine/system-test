# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_filtered_base'

class AnnCohereFilteredQuantizedPerfTest < CohereFilteredBase

  def setup
    super
    set_owner("boeker")
  end

  def test_cohere_filtered_quantized
    num_documents = 2_000_000 # The first vectors of cohere/cohere-data/docs_*.fvecs are used
    num_queries_for_benchmark = 1000
    num_queries_for_recall = 100 # The first queries used for benchmarking
    target_hits = 100
    hnsw_settings = [
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.01}
    ]

    # Smaller values that can be used for development and testing
    #num_documents = 10_000
    #num_queries_for_recall = 10

    # How the values of each query case (see run_*_test) are used in the requests, and in the labels and parameters of the reports
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration})
    set_label_format("q%{quantization_bits}-%{algorithm}-th%{target_hits}-%{filter}-hr%{hit_ratio}-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}")
    set_report_parameters({"quantization_bits" => :quantization_bits,
                           "algorithm" => :algorithm,
                           "target_hits" => :target_hits,
                           "filter" => :filter,
                           "hit_ratio" => :hit_ratio,
                           "cluster_level" => :cluster_level,
                           "approximate_threshold" => :approximate_threshold,
                           "filter_first_threshold" => :filter_first_threshold,
                           "filter_first_exploration" => :filter_first_exploration})

    set_description("Test performance and recall of nearestNeighbor (hnsw) over 4-bit quantized vectors with filters that are not, positively, and negatively correlated with the query vector " +
                    "over #{num_documents} Cohere Wikipedia embeddings (1024 dim)")
    run_filtered_test(schema: "filtered_quantized",
                      num_documents: num_documents,
                      num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall,
                      target_hits: target_hits,
                      hnsw_settings: hnsw_settings,
                      extra_values: {:quantization_bits => 4}, # As in the schema
                      nnr: {"exactField" => "embedding_f32"}) # Full-precision vectors as the exact ground truth
  end

end
