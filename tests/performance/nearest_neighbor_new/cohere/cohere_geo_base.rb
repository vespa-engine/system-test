# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_base'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with geoLocation filters: the documents within a radius
# around the location of the query. The schema needs the position field 'latlng' (see schemas/geo/).
#
# The documents and queries are at random locations in the bounding box of the contiguous United States (the default of
# the geo generators, the queries use a different random seed than the documents). The radii range from part of a city to
# half of the country (see generators/make_geo_queries.cpp).
class CohereGeoBase < CohereBase

  # Radii in km (see generators/make_geo_queries.cpp for the fraction of the documents within each radius)
  RADII = [2000, # half of the country
           1100, # a large region, e.g., around Kansas City reaching Denver, Chicago, and Dallas
           500,  # multiple states, e.g., the Pacific Northwest
           200,  # a state such as Pennsylvania or Ohio
           75,   # multiple cities, e.g., the San Francisco Bay Area
           15,   # a city such as Chicago or Los Angeles
           2]    # part of a city (with 2M documents, 20% of the queries have no document within the radius)

  # settings: list of settings, each benchmarked for every radius, e.g.,
  #   [{:name => "hnsw", :target_hits => 100, :approximate_threshold => 0.0, :filter_first_threshold => 0.2,
  #     :filter_first_exploration => 0.01}]
  #   :name names the setting in labels and reports, e.g., "hnsw" or "brute_force", :target_hits is targetHits of the
  #   queries and the number of hits compared when calculating the recall, :approximate (optional, default true) is false
  #   for exact search, and :explore_hits (optional, default 0) is hnsw.exploreAdditionalHits of the queries.
  #   The other values are used by the request parameters, label, and report parameters set by the test.
  def run_geo_test(schema:, num_documents:, num_queries_for_benchmark:, num_queries_for_recall:,
                   settings:)
    setup_cohere_test(schema: schema, num_documents: num_documents, num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall)
    feed_documents("make_geo_docs", "")

    results = {} # setting => {radius => {:recall, :qps, :avg_ms, :p95_ms}}
    settings.each do |setting|
      results[setting] = {}
      RADII.each do |radius|
        values = {:approximate => true, :explore_hits => 0}.merge(setting).merge({:radius_km => radius})
        query_file = write_queries("make_geo_queries", "--radius #{radius}", values)
        results[setting][radius] = benchmark_and_calc_recall(query_file, values, num_queries_for_recall)
      end
    end

    settings.each do |setting|
      print_results(results[setting], num_documents, setting)
    end
  end

  # Prints a table of the results of one setting: one row per radius (recall, qps, avg ms, p95 ms).
  # The title contains the number of documents and the setting.
  def print_results(results, num_documents, setting)
    title = "Results for #{num_documents} documents: " + setting.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["radius", "recall", "qps", "avg ms", "p95 ms"]]
    rows = RADII.map do |radius|
      result = results[radius]
      ["#{radius} km",
       format('%.1f', result[:recall]), format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
    end
    notes = ["(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)"]
    print_table(title, headers, rows, notes)
  end

end
