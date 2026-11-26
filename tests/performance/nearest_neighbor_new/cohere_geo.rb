# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere_base'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with geoLocation filters: the documents within a radius
# around the location of the query. The schema needs the position field 'latlng' (see schemas/cohere_geo/).
#
# The documents and queries are at random locations in the bounding box of the contiguous United States (the default of
# the geo generators, the queries use a different random seed than the documents). The radii range from part of a city to
# half of the country (see generators/make_geo_queries.cpp).
class AnnCohereGeoPerfTest < CohereBase

  def setup
    super
    set_owner("boeker")
    @num_documents = 2_000_000 # The first vectors of cohere-data/docs_*.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000
    @num_queries_for_recall = 100 # e.g., 10 for development
    # Radii in km (see generators/make_geo_queries.cpp for the fraction of the documents within each radius)
    @radii = [2000, # half of the country
              1100, # a large region, e.g., around Kansas City reaching Denver, Chicago, and Dallas
              500,  # multiple states, e.g., the Pacific Northwest
              200,  # a state such as Pennsylvania or Ohio
              75,   # multiple cities, e.g., the San Francisco Bay Area
              15,   # a city such as Chicago or Los Angeles
              2]    # part of a city (with 2M documents, 20% of the queries have no document within the radius)
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration,
                            "ranking.matching.lazyFilter" => :lazy_filter})
  end

  def test_cohere_geo
    settings = [
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.01, :lazy_filter => false}
    ]

    set_label_format("%{name}-th%{target_hits}-geo-r%{radius_km}km-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}-lf%{lazy_filter}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) with geoLocation filters " +
                    "over Cohere Wikipedia embeddings (1024 dim)")
    run_geo_test(schema: "cohere_geo",
                 settings: settings)
  end

  # schema: the schema in schemas/<schema>/test.sd
  # settings: the HNSW settings to benchmark, e.g., target hits, exploration, and filter-first threshold
  def run_geo_test(schema:, settings:)
    setup_cohere_test(schema)
    feed_documents("make_geo_docs", "")

    results = {} # setting => {radius => {:recall, :qps, :avg_ms, :p95_ms}}
    settings.each do |setting|
      results[setting] = {}
      @radii.each do |radius|
        values = {:approximate => true, :explore_hits => 0}.merge(setting).merge({:radius_km => radius})
        query_file = write_queries("make_geo_queries", "--radius #{radius}", values)
        results[setting][radius] = benchmark_and_calc_recall(query_file, values, @num_queries_for_recall)
      end
    end

    settings.each do |setting|
      print_results(results[setting], setting)
    end
  end

  # Prints a table of the results of one setting: one row per radius (recall, qps, avg ms, p95 ms).
  # The title contains the number of documents and the setting.
  def print_results(results, setting)
    title = "Results for #{@num_documents} documents: " + setting.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["radius", "recall", "qps", "avg ms", "p95 ms"]]
    rows = @radii.map do |radius|
      result = results[radius]
      ["#{radius} km",
       format('%.1f', result[:recall]), format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
    end
    notes = ["(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)"]
    print_table(title, headers, rows, notes)
  end

end
