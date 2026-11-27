# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/ann_filtered'
require 'performance/nearest_neighbor_ng/dataset_cohere'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with uncorrelated, positively, and negatively correlated
# filters (see AnnFiltered). The schema needs the array<int> field 'filter' and the int fields cluster_<level>
# (see schemas/cohere_filtered/).
class AnnCohereFilteredPerfTest < AnnFiltered
  include DatasetCohere

  def setup
    super
    set_owner("boeker")
    @num_documents = 1_000_000 # The first vectors of cohere-data/docs_*.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000
    @num_queries_for_recall = 100 # e.g., 10 for development
    @hit_ratios = [0.9, 0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001]
  end

  def test_cohere_filtered
    set_description("Test performance and recall of nearestNeighbor (hnsw) with filters that are not, positively, and negatively correlated with the query vector " +
                    "over Cohere Wikipedia embeddings (1024 dim)")

    test_parameters = [
      {:name => "hnsw", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00, :filter_first_exploration => 0.10},
      {:name => "ff", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.00, :filter_first_threshold => 1.00, :filter_first_exploration => 0.10},
      {:name => "hnsw-ff-exact", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.02, :filter_first_threshold => 0.25, :filter_first_exploration => 0.10}
    ]

    set_label_format("%{name}-th%{target_hits}-%{filter_type}-hr%{hit_ratio}-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}")

    setup_filtered_test("cohere_filtered")
    run_benchmarks_unfiltered(test_parameters)
    run_benchmarks_uncorrelated(test_parameters)
    run_benchmarks_correlated(test_parameters)
    print_results
  end

end
