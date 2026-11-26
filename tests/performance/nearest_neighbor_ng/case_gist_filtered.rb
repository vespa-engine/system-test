# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/ann_filtered'
require 'performance/nearest_neighbor_ng/dataset_gist'

# Tests nearest neighbor search (HNSW vs. brute force) over the GIST vectors without a filter and with uncorrelated filters
# (see AnnFiltered). The schema needs the array<int> field 'filter' (see schemas/gist_filtered/).
class AnnGistFilteredPerfTest < AnnFiltered
  include DatasetGist

  def setup
    super
    set_owner("boeker")
    @num_documents = 300_000 # All vectors of gist-data/gist_base_300k.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000 # All vectors of gist-data/gist_query.fvecs
    @num_queries_for_recall = 100 # e.g., 10 for development
    @hit_ratios = [0.99, 0.5, 0.1, 0.05, 0.01, 0.005, 0.001]
  end

  def test_gist_filtered
    test_parameters = [
      # Exact search as the baseline for the performance
      {:name => "brute_force", :approximate => false, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00, :filter_first_exploration => 0.3},
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.3},
      # The same with more exploration
      {:name => "hnsw", :approximate => true, :target_hits => 100, :explore_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.3}
    ]

    set_label_format("%{name}-th%{target_hits}-eh%{explore_hits}-hr%{hit_ratio}-at%{approximate_threshold}-fft%{filter_first_threshold}")

    set_description("Test performance and recall of nearestNeighbor (hnsw vs brute force) without and with filters " +
                    "over GIST vectors (960 dim, 300k of 1M fed)")
    setup_filtered_test("gist_filtered")
    run_unfiltered_test(test_parameters)
    run_uncorrelated_test(test_parameters)
    print_results
  end

end
