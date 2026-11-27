# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/ann_base'

# Base class for tests of nearest neighbor search with geoLocation filters: the documents within a radius around the
# location of the query. The test sets @radii (in km) and runs
#   setup_geo_test(schema)
#   run_benchmarks_geo(test_parameters)
#   print_results
#
# The data set module provides:
#   feed_geo_documents                 feeds the documents with the position field 'latlng'
#   write_geo_queries(radius, values)  writes the queries with a geoLocation filter with the radius
#
# The documents and queries are at random locations in the bounding box of the contiguous United States (the default of
# the geo generators, the queries use a different random seed than the documents). See generators/make_geo_queries.cpp
# for the fraction of the documents within a radius.
class AnnGeo < AnnBase

  # The request parameters of all geo tests, so each benchmark needs the values :target_hits, :approximate_threshold,
  # :filter_first_threshold, :filter_first_exploration, and :lazy_filter
  def setup
    super
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "timeout" => "20s",
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration,
                            "ranking.matching.lazyFilter" => :lazy_filter})
  end

  # Deploys the schema in schemas/<schema>/test.sd, starts Vespa, and feeds the documents.
  # substitutions: placeholders in the schema to replace (see AnnBase#setup_test)
  def setup_geo_test(schema, threads_per_search: 1, substitutions: {})
    setup_test(schema, threads_per_search: threads_per_search, substitutions: substitutions)
    feed_geo_documents
    @results = {} # parameters => {radius => {:recall, :qps, :avg_ms, :p95_ms}}
  end

  # test_parameters: the parameters to benchmark (one hash each), with :approximate, :target_hits, and :explore_hits for the
  # nearestNeighbor operator, and, e.g., the approximate and filter-first thresholds
  def run_benchmarks_geo(test_parameters)
    test_parameters.each do |parameters|
      @radii.each do |radius|
        values = parameters.merge({:radius_km => radius})
        query_file = write_geo_queries(radius, values)
        (@results[parameters] ||= {})[radius] = benchmark_and_calc_recall(query_file, values, @num_queries_for_recall)
      end
    end
  end

  # Prints a table of the results for each set of test parameters: one row per radius.
  def print_results
    @results.each do |parameters, results|
      rows = @radii.map { |radius| ["#{radius} km"] + result_cells(results[radius]) }
      print_table(results_title(parameters), [["radius"] + RESULT_HEADERS], rows, [RESULT_NOTE])
    end
  end

end
