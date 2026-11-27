# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/ann_geo'
require 'performance/nearest_neighbor_ng/dataset_cohere'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with geoLocation filters (see AnnGeo and
# schemas/cohere_geo/).
class AnnCohereGeoPerfTest < AnnGeo
  include DatasetCohere

  def setup
    super
    set_owner("boeker")
    @num_documents = 1_000_000 # The first vectors of cohere-data/docs_*.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000
    @num_queries_for_recall = 100 # e.g., 10 for development
    # Radii in km (see generators/make_geo_queries.cpp for the fraction of the documents within each radius)
    @radii = [2000, # half of the country
              1100, # a large region, e.g., around Kansas City reaching Denver, Chicago, and Dallas
              500,  # multiple states, e.g., the Pacific Northwest
              200,  # a state such as Pennsylvania or Ohio
              75,   # multiple cities, e.g., the San Francisco Bay Area
              30,
              15,   # a city such as Chicago or Los Angeles
              2]    # part of a city (with 2M documents, 20% of the queries have no document within the radius)
  end

  def test_cohere_geo
    set_description("Test performance and recall of nearestNeighbor (hnsw) with geoLocation filters " +
                    "over Cohere Wikipedia embeddings (1024 dim)")

    test_parameters = [
      {:name => "hnsw-ff-exact", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.02, :filter_first_threshold => 0.25, :filter_first_exploration => 0.10, :lazy_filter => false},
      {:name => "hnsw-ff-exact", :approximate => true, :target_hits => 100, :explore_hits => 0,
       :approximate_threshold => 0.02, :filter_first_threshold => 0.25, :filter_first_exploration => 0.10, :lazy_filter => true}
    ]

    set_label_format("%{name}-th%{target_hits}-geo-r%{radius_km}km-lf%{lazy_filter}")

    setup_geo_test("cohere_geo")
    run_benchmarks_geo(test_parameters)
    print_results
  end

end
