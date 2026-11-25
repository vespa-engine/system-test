# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_base'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with filters that are
#   uncorrelated: on the field 'filter' (by document id), not correlated with the query vector
#   positive:     'cluster_<level> in (...)', restricted to the clusters closest to the query vector
#   negative:     'cluster_<level> in (...)', restricted to the clusters farthest from the query vector
# for different hit ratios (fraction of the documents passing the filter). The schema needs the array<int> field 'filter'
# and the int fields cluster_<level> (see schemas/filtered/).
#
# make_filtered_queries selects the closest or farthest clusters (from ranked_<level>.ivecs) of each query vector until they
# contain the target fraction of the fed documents, such that the hit ratio is correct for any number of documents.
# A query restricted to its clusters contains about (hit ratio * number of clusters) terms, so each hit ratio uses the
# cluster level that gives about 5 to 25 clusters per query (see cluster_level).
class CohereFilteredBase < CohereBase

  UNCORRELATED = "uncorrelated"
  POSITIVE = "positive"
  NEGATIVE = "negative"
  FILTERS = [UNCORRELATED, POSITIVE, NEGATIVE]

  HIT_RATIOS = [0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001]

  # target_hits: targetHits of the queries, and the number of hits compared when calculating the recall
  # hnsw_settings: list of settings, each benchmarked for every filter and hit ratio, e.g.,
  #   [{:approximate_threshold => 0.0, :filter_first_threshold => 0.2, :filter_first_exploration => 0.01}]
  # extra_values: values of the test that are added to the values of every query case (for the label and reports set by
  #   the test), e.g., {:quantization_bits => 4}
  # nnr: additional parameters for NearestNeighborRecallSearcher when calculating the recall, e.g., {"exactField" => "embedding_f32"}
  #   for the exact search over a full-precision copy of a quantized field
  def run_filtered_test(schema:, num_documents:, num_queries_for_benchmark:, num_queries_for_recall:,
                        target_hits:, hnsw_settings:, extra_values: {}, nnr: {})
    setup_cohere_test(schema: schema, num_documents: num_documents, num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall, extra_values: extra_values)
    clusters_fine, clusters_medium, clusters_coarse = download_cluster_files(vespa.adminserver)
    feed_documents("make_filtered_docs",
                   "--filter-values #{HIT_RATIOS.map { |hit_ratio| uncorrelated_filter_value(hit_ratio) }.join(',')} " +
                   "--filter-denominator #{UNCORRELATED_FILTER_DENOMINATOR} " +
                   "--cluster-files #{clusters_fine},#{clusters_medium},#{clusters_coarse} " +
                   "--cluster-fields cluster_fine,cluster_medium,cluster_coarse")

    query_files = {} # [filter, hit_ratio] => query file on the container, the same for all settings
    FILTERS.each do |filter|
      HIT_RATIOS.each do |hit_ratio|
        query_files[[filter, hit_ratio]] = generate_queries(filter, hit_ratio, target_hits)
      end
    end

    results = {} # settings => {[filter, hit_ratio] => {:recall, :qps, :avg_ms, :p95_ms}}
    hnsw_settings.each do |settings|
      results[settings] = {}
      FILTERS.each do |filter|
        HIT_RATIOS.each do |hit_ratio|
          values = settings.merge(extra_values).merge({:target_hits => target_hits,
                                                       :filter => filter,
                                                       :hit_ratio => hit_ratio,
                                                       :cluster_level => (filter == UNCORRELATED) ? "none" : cluster_level(hit_ratio)})
          results[settings][[filter, hit_ratio]] =
            benchmark_and_calc_recall(query_files[[filter, hit_ratio]], values, num_queries_for_recall, algorithm: HNSW, nnr: nnr)
        end
      end
    end

    hnsw_settings.each do |settings|
      print_results(results[settings], num_documents, extra_values.merge({:target_hits => target_hits}).merge(settings))
    end
  end

  # Prints a table of the results of one settings: one row per hit ratio, with the results for each filter side by side
  # (recall, qps, avg ms, p95 ms). The title contains the number of documents and the values of the table.
  def print_results(results, num_documents, table_values)
    title = "Results for #{num_documents} documents: " + table_values.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["", ""] + FILTERS.flat_map { |filter| [filter, "", "", ""] },
               ["hit ratio", "level"] + FILTERS.flat_map { ["recall", "qps", "avg ms", "p95 ms"] }]
    rows = HIT_RATIOS.map do |hit_ratio|
      result_cells = FILTERS.flat_map do |filter|
        result = results[[filter, hit_ratio]]
        [format('%.1f', result[:recall]), format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
      end
      [format('%g%%', hit_ratio * 100), cluster_level(hit_ratio)] + result_cells
    end
    notes = ["(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)",
             "(level: cluster level of the positive and negative filters)"]
    print_table(title, headers, rows, notes)
  end

  # Generates the queries with the filter and hit ratio, and returns the query file on the container.
  def generate_queries(filter, hit_ratio, target_hits)
    file_name = "queries.#{filter}.#{hit_ratio}.txt"
    if filter == UNCORRELATED
      return write_queries("make_filtered_queries", target_hits, "--filter-value #{uncorrelated_filter_value(hit_ratio)}", file_name)
    end

    level = cluster_level(hit_ratio)
    ranked_clusters = find_or_download_compressed_file(RANKED_CLUSTERS_FILES[level], container, **DATA_DIRS)
    doc_clusters = find_or_download_compressed_file(CLUSTERS_FILES[level], container, **DATA_DIRS)
    selection = (filter == POSITIVE) ? "closest" : "farthest"
    write_queries("make_filtered_queries", target_hits,
                  "--ranked-clusters #{ranked_clusters} --doc-clusters #{doc_clusters} --num-docs #{@num_documents} " +
                  "--cluster-field cluster_#{level} --selection #{selection} --target-fraction #{hit_ratio}",
                  file_name)
  end

  # Returns the cluster level (the field cluster_<level>) used for the positive and negative filters with the hit ratio.
  # The level is chosen such that the queries contain about 5 to 25 clusters (hit ratio * number of clusters of the level),
  # which keeps the queries small while the selected clusters contain close to the target fraction of the documents.
  # For hit ratios below 0.005, there are only a few clusters per query, so the selected clusters can contain several
  # times the target fraction (e.g., about 1 to 4 clusters for 0.001).
  def cluster_level(hit_ratio)
    if hit_ratio >= 0.2
      "coarse" # 50 clusters
    elsif hit_ratio >= 0.05
      "medium" # 200 clusters
    else
      "fine" # 1000 clusters
    end
  end

  # The generators define the uncorrelated filter by filter values instead of hit ratios: a document gets value v in the
  # field 'filter' if (id % denominator) >= v, so 'filter=v' has hit ratio 1 - v / denominator. This method converts a
  # hit ratio to its filter value for the generators, the test uses hit ratios everywhere else.
  UNCORRELATED_FILTER_DENOMINATOR = 1000 # Supports hit ratios that are multiples of 0.001

  def uncorrelated_filter_value(hit_ratio)
    value = (1 - hit_ratio) * UNCORRELATED_FILTER_DENOMINATOR
    assert((value - value.round).abs < 1e-9, "Hit ratio #{hit_ratio} is not a multiple of 1 / #{UNCORRELATED_FILTER_DENOMINATOR}")
    value.round
  end

end
