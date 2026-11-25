# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_geo_base'

class AnnCohereGeoPerfTest < CohereGeoBase

  def setup
    super
    set_owner("boeker")
  end

  def test_cohere_geo
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
    set_label_format("%{algorithm}-th%{target_hits}-geo-r%{radius_km}km-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}")
    set_report_parameters({"algorithm" => :algorithm,
                           "target_hits" => :target_hits,
                           "radius_km" => :radius_km,
                           "approximate_threshold" => :approximate_threshold,
                           "filter_first_threshold" => :filter_first_threshold,
                           "filter_first_exploration" => :filter_first_exploration})

    set_description("Test performance and recall of nearestNeighbor (hnsw) with geoLocation filters " +
                    "over #{num_documents} Cohere Wikipedia embeddings (1024 dim)")
    run_geo_test(schema: "geo",
                 num_documents: num_documents,
                 num_queries_for_benchmark: num_queries_for_benchmark,
                 num_queries_for_recall: num_queries_for_recall,
                 target_hits: target_hits,
                 hnsw_settings: hnsw_settings)
  end

end
