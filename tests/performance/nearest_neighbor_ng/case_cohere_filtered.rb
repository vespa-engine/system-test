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
    @num_documents = 2_000_000 # The first vectors of cohere-data/docs_*.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000
    @num_queries_for_recall = 100 # e.g., 10 for development
    @hit_ratios = [0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001]
  end

  def test_cohere_filtered
    test_parameters = [
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.01}
    ]

    set_label_format("%{name}-th%{target_hits}-%{filter_type}-hr%{hit_ratio}-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) with filters that are not, positively, and negatively correlated with the query vector " +
                    "over Cohere Wikipedia embeddings (1024 dim)")
    setup_filtered_test("cohere_filtered")
    run_unfiltered_test(test_parameters)
    run_uncorrelated_test(test_parameters)
    run_correlated_test(test_parameters)
    print_results
  end

  def test_cohere_filtered_quantized_4_bits
    run_quantized_test(bits: 4)
  end

  # bits: the quantization level of the vectors (see %{QUANTIZATION_BITS} in schemas/cohere_filtered_quantized/)
  def run_quantized_test(bits:)
    test_parameters = [
      # Always use HNSW, without the filter-first heuristic
      {:name => "hnsw-q#{bits}", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00, :filter_first_exploration => 0.01}
    ]

    set_label_format("%{name}-th%{target_hits}-%{filter_type}-hr%{hit_ratio}-at%{approximate_threshold}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) over #{bits}-bit quantized vectors with filters that are not, positively, and negatively correlated with the query vector " +
                    "over Cohere Wikipedia embeddings (1024 dim)")
    setup_filtered_test("cohere_filtered_quantized",
                        substitutions: {"QUANTIZATION_BITS" => bits},
                        nnr: {"exactField" => "embedding_f32"}) # Full-precision vectors as the exact ground truth
    run_unfiltered_test(test_parameters)
    run_uncorrelated_test(test_parameters)
    run_correlated_test(test_parameters)
    print_results
  end

end
