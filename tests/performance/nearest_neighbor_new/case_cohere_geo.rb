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
    # Each setting is benchmarked for every query case. :name names the setting in labels and reports. Optionally,
    # :approximate => false uses exact search, and :explore_hits sets hnsw.exploreAdditionalHits (default 0).
    settings = [
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.01, :lazy_filter => false}
    ]

    # Smaller values that can be used for development and testing
    #num_documents = 10_000
    #num_queries_for_recall = 10

    # How the values of each query case (see run_*_test) are used in the requests and in the labels of the reports
    # (all values are parameters of the reports)
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration,
                            "ranking.matching.lazyFilter" => :lazy_filter})
    set_label_format("%{name}-th%{target_hits}-geo-r%{radius_km}km-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}-lf%{lazy_filter}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) with geoLocation filters " +
                    "over #{num_documents} Cohere Wikipedia embeddings (1024 dim)")
    run_geo_test(schema: "geo",
                 num_documents: num_documents,
                 num_queries_for_benchmark: num_queries_for_benchmark,
                 num_queries_for_recall: num_queries_for_recall,
                 settings: settings)
  end

end
