# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/sift_base'

# Tests nearest neighbor search (HNSW) over the SIFT vectors without a filter and with filters on the field 'filter' that are
# not correlated with the query vectors, for different hit ratios (fraction of the documents passing the filter).
# The schema needs the array<int> field 'filter' (see schemas/sift_filtered/).
class AnnSiftFilteredPerfTest < SiftBase

  def setup
    super
    set_owner("boeker")
    @num_documents = 1_000_000 # All vectors of sift-data/sift_base.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000
    @num_queries_for_recall = 100 # e.g., 10 for development
    @hit_ratios = [1.0, 0.5, 0.1, 0.05, 0.01, 0.005, 0.001] # 1.0: no filter
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold})
  end

  def test_sift_filtered
    settings = [
      # Exact search as the baseline for the performance
      {:name => "brute_force", :approximate => false, :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00},
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20},
      # The same with more exploration
      {:name => "hnsw", :target_hits => 100, :explore_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20}
    ]

    set_label_format("%{name}-th%{target_hits}-eh%{explore_hits}-hr%{hit_ratio}-at%{approximate_threshold}-fft%{filter_first_threshold}")

    set_description("Test performance and recall of nearestNeighbor (hnsw vs brute force) without and with filters " +
                    "over SIFT vectors (128 dim)")
    run_filtered_test(schema: "sift_filtered",
                      settings: settings)
  end

  # schema: the schema in schemas/<schema>/test.sd
  # settings: the HNSW settings to benchmark, e.g., target hits, exploration, and filter-first threshold
  def run_filtered_test(schema:, settings:)
    setup_sift_test(schema)
    feed_documents("make_filtered_docs", "--hit-ratios #{@hit_ratios.reject { |hit_ratio| hit_ratio == 1.0 }.join(',')}")

    results = {} # setting => {hit_ratio => {:recall, :qps, :avg_ms, :p95_ms}}
    settings.each do |setting|
      results[setting] = {}
      @hit_ratios.each do |hit_ratio|
        values = {:approximate => true, :explore_hits => 0}.merge(setting).merge({:hit_ratio => hit_ratio})
        query_file = generate_queries(hit_ratio, values)
        results[setting][hit_ratio] = benchmark_and_calc_recall(query_file, values, @num_queries_for_recall)
      end
    end

    settings.each do |setting|
      print_results(results[setting], setting)
    end
  end

  # Generates the queries with a filter with the hit ratio (no filter for 1.0) for the benchmark, and returns the query file
  # on the container.
  def generate_queries(hit_ratio, values)
    if hit_ratio == 1.0
      return write_queries("make_filtered_queries", "", values)
    end

    write_queries("make_filtered_queries", "--hit-ratio #{hit_ratio}", values)
  end

  # Prints a table of the results of one setting: one row per hit ratio (recall, qps, avg ms, p95 ms).
  # The title contains the number of documents and the setting.
  def print_results(results, setting)
    title = "Results for #{@num_documents} documents: " + setting.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["hit ratio", "recall", "qps", "avg ms", "p95 ms"]]
    rows = @hit_ratios.map do |hit_ratio|
      result = results[hit_ratio]
      [(hit_ratio == 1.0) ? "no filter" : format('%g%%', hit_ratio * 100),
       format('%.1f', result[:recall]), format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
    end
    notes = ["(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)"]
    print_table(title, headers, rows, notes)
  end

end
