# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_ng/ann_base'

# Base class for tests of nearest neighbor search with filters, for different hit ratios (fraction of the documents passing
# the filter). The test sets @hit_ratios and runs
#   setup_filtered_test(schema)
#   run_benchmarks_unfiltered(test_parameters)    no filter, without calculating the recall (e.g., as a warm-up)
#   run_benchmarks_uncorrelated(test_parameters)  filters on the array<int> field 'filter' (by document id), not correlated with the query vector
#   run_benchmarks_correlated(test_parameters)    filters restricted to the clusters closest (positive) or farthest (negative) from the query vector
#   print_results
#
# The data set module provides:
#   feed_filtered_documents(hit_ratios)                       feeds the documents with filter fields for the hit ratios
#   write_unfiltered_queries(values)                          writes the queries without a filter
#   write_uncorrelated_queries(hit_ratio, values)             writes the queries with an uncorrelated filter
#   write_correlated_queries(filter_type, hit_ratio, values)  writes the queries with a POSITIVE or NEGATIVE filter
#   cluster_level(hit_ratio)                                  the cluster level of the correlated filters (shown in the results)
class AnnFiltered < AnnBase

  UNFILTERED = "unfiltered"
  UNCORRELATED = "uncorrelated"
  POSITIVE = "positive"
  NEGATIVE = "negative"

  # The request parameters of all filtered tests, so each benchmark needs the values :target_hits, :approximate_threshold,
  # :filter_first_threshold, and :filter_first_exploration
  def setup
    super
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "timeout" => "20s",
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration})
  end

  # Deploys the schema in schemas/<schema>/test.sd, starts Vespa, and feeds the documents.
  # nnr: additional NearestNeighborRecallSearcher parameters without the prefix 'nnr.', e.g., {"exactField" => "embedding_f32"}
  # substitutions: placeholders in the schema to replace (see AnnBase#setup_test)
  def setup_filtered_test(schema, threads_per_search: 1, nnr: {}, substitutions: {})
    setup_test(schema, threads_per_search: threads_per_search, substitutions: substitutions)
    feed_filtered_documents(@hit_ratios)
    @nnr = nnr
    @unfiltered_results = {} # parameters => {:qps, :avg_ms, :p95_ms}
    @results = {} # parameters => {[filter_type, hit_ratio] => {:recall, :qps, :avg_ms, :p95_ms}}
    @cluster_levels = {} # hit_ratio => the cluster level of the correlated filters
  end

  # test_parameters: the parameters to benchmark (one hash each), with :approximate, :target_hits, and :explore_hits for the
  # nearestNeighbor operator, and, e.g., the approximate and filter-first thresholds
  def run_benchmarks_unfiltered(test_parameters)
    test_parameters.each do |parameters|
      values = parameters.merge({:filter_type => UNFILTERED, :hit_ratio => 1.0})
      query_file = write_unfiltered_queries(values)
      @unfiltered_results[parameters] = benchmark(query_file, values)
    end
  end

  def run_benchmarks_uncorrelated(test_parameters)
    run_benchmarks(test_parameters, [UNCORRELATED], @hit_ratios) do |filter_type, hit_ratio, values|
      write_uncorrelated_queries(hit_ratio, values)
    end
  end

  def run_benchmarks_correlated(test_parameters)
    @hit_ratios.each { |hit_ratio| @cluster_levels[hit_ratio] = cluster_level(hit_ratio) }
    run_benchmarks(test_parameters, [POSITIVE, NEGATIVE], @hit_ratios) do |filter_type, hit_ratio, values|
      write_correlated_queries(filter_type, hit_ratio, values)
    end
  end

  # Benchmarks the queries written by the block for each combination of parameters, filter type, and hit ratio.
  def run_benchmarks(test_parameters, filter_types, hit_ratios)
    test_parameters.each do |parameters|
      filter_types.each do |filter_type|
        hit_ratios.each do |hit_ratio|
          values = parameters.merge({:filter_type => filter_type, :hit_ratio => hit_ratio})
          query_file = yield(filter_type, hit_ratio, values)
          (@results[parameters] ||= {})[[filter_type, hit_ratio]] =
            benchmark_and_calc_recall(query_file, values, @num_queries_for_recall, nnr: @nnr)
        end
      end
    end
  end

  # Prints a table of the unfiltered results (one row per set of test parameters), and a table of the filtered results for
  # each set of test parameters: one row per hit ratio, with the results for each filter type side by side.
  def print_results
    unless @unfiltered_results.empty?
      rows = @unfiltered_results.map do |parameters, result|
        [parameters.map { |key, value| "#{key} #{value}" }.join(", ")] + benchmark_cells(result)
      end
      print_table("Results for #{@num_documents} documents without filter:", [["parameters"] + BENCHMARK_HEADERS], rows, [BENCHMARK_NOTE])
    end

    @results.each do |parameters, results|
      filter_types = results.keys.map(&:first).uniq
      show_levels = !@cluster_levels.empty?
      first_headers = show_levels ? ["hit ratio", "level"] : ["hit ratio"]
      headers = [[""] * first_headers.size + filter_types.flat_map { |filter_type| [filter_type] + [""] * (RESULT_HEADERS.size - 1) },
                 first_headers + filter_types.flat_map { RESULT_HEADERS }]
      rows = @hit_ratios.map do |hit_ratio|
        first_cells = [format('%g%%', hit_ratio * 100)]
        first_cells << @cluster_levels[hit_ratio] if show_levels
        first_cells + filter_types.flat_map { |filter_type| result_cells(results[[filter_type, hit_ratio]]) }
      end
      notes = [RESULT_NOTE]
      notes << "(level: cluster level of the positive and negative filters)" if show_levels
      print_table(results_title(parameters), headers, rows, notes)
    end
  end

end
