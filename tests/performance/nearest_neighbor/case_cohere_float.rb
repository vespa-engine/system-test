# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/ann_cohere_base'

class AnnCoherePerfTest < AnnCohereBase

  def setup
    super
    set_owner("boeker")
  end

  def test_cohere_filtered_data_set
    num_documents = 1_000_000 # The first vectors of cohere-data/docs.fvecs are used
    num_queries_for_recall = 100

    # Smaller values that can be used for development and testing
    #num_documents = 10_000
    #num_queries_for_recall = 10

    set_description("Test performance and recall using nearestNeighbor operator (hnsw vs brute force) with filters " +
                    "that are not, positively, and negatively correlated with the query vector " +
                    "over #{num_documents} Cohere Wikipedia embeddings (1024 dim)")
    run_cohere_filter_test("cohere_test", num_documents, num_queries_for_recall)
  end

end
