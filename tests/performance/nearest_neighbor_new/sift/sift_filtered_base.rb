# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/sift/sift_base'

# Tests nearest neighbor search (HNSW) over the SIFT vectors without a filter and with filters on the field 'filter' that are
# not correlated with the query vectors, for different hit ratios (fraction of the documents passing the filter).
# The schema needs the array<int> field 'filter' (see schemas/filtered/).
class SiftFilteredBase < SiftBase

  # hit_ratios: the hit ratios benchmarked, e.g., [1.0, 0.1, 0.01], where 1.0 means no filter. The other hit ratios must be
  #   multiples of 0.001, as the filters are defined per 1000 documents: for hit ratio r, document i contains r * 1000 in the
  #   field 'filter' if (i % 1000) < r * 1000, and the queries add 'filter=<r * 1000>' (see common/generators/shared.h).
  # settings: list of settings, each benchmarked for every hit ratio, e.g.,
  #   [{:name => "hnsw", :target_hits => 100, :explore_hits => 100, :approximate_threshold => 0.05}]
  #   :name names the setting in labels and reports, e.g., "hnsw" or "brute_force", :target_hits is targetHits of the
  #   queries and the number of hits compared when calculating the recall, :approximate (optional, default true) is false
  #   for exact search, and :explore_hits (optional, default 0) is hnsw.exploreAdditionalHits of the queries.
  #   The other values are used by the request parameters, label, and report parameters set by the test.
  def run_filtered_test(schema:, num_documents:, num_queries_for_benchmark:, num_queries_for_recall:, hit_ratios:, settings:)
    setup_sift_test(schema: schema, num_documents: num_documents, num_queries_for_benchmark: num_queries_for_benchmark,
                    num_queries_for_recall: num_queries_for_recall)
    feed_documents("make_filtered_docs", "--hit-ratios #{hit_ratios.reject { |hit_ratio| hit_ratio == 1.0 }.join(',')}")

    results = {} # setting => {hit_ratio => {:recall, :qps, :avg_ms, :p95_ms}}
    settings.each do |setting|
      results[setting] = {}
      hit_ratios.each do |hit_ratio|
        values = {:approximate => true, :explore_hits => 0}.merge(setting).merge({:hit_ratio => hit_ratio})
        query_file = generate_queries(hit_ratio, values)
        results[setting][hit_ratio] = benchmark_and_calc_recall(query_file, values, num_queries_for_recall)
      end
    end

    settings.each do |setting|
      print_results(results[setting], num_documents, hit_ratios, setting)
    end
  end

  # Generates the queries with a filter with the hit ratio (no filter for 1.0) for the query case, and returns the query file
  # on the container.
  def generate_queries(hit_ratio, values)
    if hit_ratio == 1.0
      return write_queries("make_filtered_queries", "", values)
    end

    write_queries("make_filtered_queries", "--hit-ratio #{hit_ratio}", values)
  end

  # Prints a table of the results of one setting: one row per hit ratio (recall, qps, avg ms, p95 ms).
  # The title contains the number of documents and the setting.
  def print_results(results, num_documents, hit_ratios, setting)
    title = "Results for #{num_documents} documents: " + setting.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["hit ratio", "recall", "qps", "avg ms", "p95 ms"]]
    rows = hit_ratios.map do |hit_ratio|
      result = results[hit_ratio]
      [(hit_ratio == 1.0) ? "no filter" : format('%g%%', hit_ratio * 100),
       format('%.1f', result[:recall]), format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
    end
    notes = ["(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)"]
    print_table(title, headers, rows, notes)
  end

end
