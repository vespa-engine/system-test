# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/sift/sift_filtered_base'

class AnnSiftFilteredPerfTest < SiftFilteredBase

  def setup
    super
    set_owner("boeker")
  end

  def test_sift_filtered
    num_documents = 1_000_000 # All vectors of sift/sift-data/sift_base.fvecs
    num_queries_for_benchmark = 1000
    num_queries_for_recall = 100 # The first queries used for benchmarking
    hit_ratios = [1.0, 0.5, 0.1, 0.05, 0.01, 0.005, 0.001] # 1.0: no filter
    settings = [
      # Exact search as the baseline for the performance
      {:name => "brute_force", :approximate => false, :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00},
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20},
      # The same with more exploration
      {:name => "hnsw", :target_hits => 100, :explore_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20}
    ]

    # Smaller values that can be used for development and testing
    #num_documents = 10_000
    #num_queries_for_recall = 10

    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold})
    set_label_format("%{name}-th%{target_hits}-eh%{explore_hits}-hr%{hit_ratio}-at%{approximate_threshold}-fft%{filter_first_threshold}")

    set_description("Test performance and recall of nearestNeighbor (hnsw vs brute force) without and with filters " +
                    "over #{num_documents} SIFT vectors (128 dim)")
    run_filtered_test(schema: "filtered",
                      num_documents: num_documents,
                      num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall,
                      hit_ratios: hit_ratios,
                      settings: settings)
  end

end
