# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_base'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with filters that are
#   uncorrelated: on the field 'filter' (by document id), not correlated with the query vector
#   positive:     'cluster_<level> in (...)', restricted to the clusters closest to the query vector
#   negative:     'cluster_<level> in (...)', restricted to the clusters farthest from the query vector
# for different hit ratios (fraction of the documents passing the filter). The schema needs the array<int> field 'filter'
# and the int fields cluster_<level> (see schemas/filtered/).
#
# make_correlated_filtered_queries selects the closest or farthest clusters (from ranked_<level>.ivecs) of each query vector until they
# contain the target fraction of the fed documents, such that the hit ratio is correct for any number of documents.
# A query restricted to its clusters contains about (hit ratio * number of clusters) terms, so each hit ratio uses the
# cluster level that gives about 5 to 25 clusters per query (see CohereBase.cluster_level).
class CohereFilteredBase < CohereBase

  UNCORRELATED = "uncorrelated"
  POSITIVE = "positive"
  NEGATIVE = "negative"
  CORRELATIONS = [UNCORRELATED, POSITIVE, NEGATIVE]

  # hit_ratios: the hit ratios benchmarked for every correlation, e.g., [0.5, 0.1, 0.01]. They must be multiples of 0.001,
  #   as the uncorrelated filters are defined per 1000 documents: for hit ratio r, document i contains r * 1000 in the field
  #   'filter' if (i % 1000) < r * 1000, and the queries add 'filter=<r * 1000>' (see common/generators/shared.h).
  # settings: list of settings, each benchmarked for every correlation and hit ratio, e.g.,
  #   [{:name => "hnsw", :target_hits => 100, :approximate_threshold => 0.0, :filter_first_threshold => 0.2,
  #     :filter_first_exploration => 0.01}]
  #   :name names the setting in labels and reports, e.g., "hnsw" or "brute_force", :target_hits is targetHits of the
  #   queries and the number of hits compared when calculating the recall, :approximate (optional, default true) is false
  #   for exact search, and :explore_hits (optional, default 0) is hnsw.exploreAdditionalHits of the queries.
  #   The other values are used by the request parameters, label, and report parameters set by the test, e.g.,
  #   :quantization_bits for quantized vectors.
  # nnr: additional parameters for NearestNeighborRecallSearcher when calculating the recall, e.g., {"exactField" => "embedding_f32"}
  #   for the exact search over a full-precision copy of a quantized field
  def run_filtered_test(schema:, num_documents:, num_queries_for_benchmark:, num_queries_for_recall:,
                        hit_ratios:, settings:, nnr: {})
    setup_cohere_test(schema: schema, num_documents: num_documents, num_queries_for_benchmark: num_queries_for_benchmark,
                      num_queries_for_recall: num_queries_for_recall)
    clusters_fine, clusters_medium, clusters_coarse = download_cluster_files(vespa.adminserver)
    feed_documents("make_filtered_docs",
                   "--hit-ratios #{hit_ratios.join(',')} " +
                   "--cluster-files #{clusters_fine},#{clusters_medium},#{clusters_coarse} " +
                   "--cluster-fields cluster_fine,cluster_medium,cluster_coarse")

    results = {} # setting => {[correlation, hit_ratio] => {:recall, :qps, :avg_ms, :p95_ms}}
    settings.each do |setting|
      results[setting] = {}
      CORRELATIONS.each do |correlation|
        hit_ratios.each do |hit_ratio|
          values = {:approximate => true, :explore_hits => 0}.merge(setting).merge(
            {:correlation => correlation, :hit_ratio => hit_ratio})
          query_file = generate_queries(correlation, hit_ratio, values)
          results[setting][[correlation, hit_ratio]] =
            benchmark_and_calc_recall(query_file, values, num_queries_for_recall, nnr: nnr)
        end
      end
    end

    settings.each do |setting|
      print_results(results[setting], num_documents, hit_ratios, setting)
    end
  end

  # Prints a table of the results of one setting: one row per hit ratio, with the results for each correlation side by side
  # (recall, qps, avg ms, p95 ms). The title contains the number of documents and the setting.
  def print_results(results, num_documents, hit_ratios, setting)
    title = "Results for #{num_documents} documents: " + setting.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["", ""] + CORRELATIONS.flat_map { |correlation| [correlation, "", "", ""] },
               ["hit ratio", "level"] + CORRELATIONS.flat_map { ["recall", "qps", "avg ms", "p95 ms"] }]
    rows = hit_ratios.map do |hit_ratio|
      result_cells = CORRELATIONS.flat_map do |correlation|
        result = results[[correlation, hit_ratio]]
        [format('%.1f', result[:recall]), format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
      end
      [format('%g%%', hit_ratio * 100), cluster_level(hit_ratio)] + result_cells
    end
    notes = ["(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)",
             "(level: cluster level of the positive and negative filters)"]
    print_table(title, headers, rows, notes)
  end

  # Generates the queries with a filter with the correlation and hit ratio for the query case, and returns the query file
  # on the container.
  def generate_queries(correlation, hit_ratio, values)
    if correlation == UNCORRELATED
      return write_queries("make_filtered_queries", "--hit-ratio #{hit_ratio}", values)
    end

    level = cluster_level(hit_ratio)
    ranked_clusters = find_or_download_compressed_file(RANKED_CLUSTERS_FILES[level], container, local_dir: LOCAL_DIR, s3_dir: S3_DIR)
    doc_clusters = find_or_download_compressed_file(CLUSTERS_FILES[level], container, local_dir: LOCAL_DIR, s3_dir: S3_DIR)
    selection = (correlation == POSITIVE) ? "closest" : "farthest"
    write_queries("make_correlated_filtered_queries",
                  "--ranked-clusters #{ranked_clusters} --doc-clusters #{doc_clusters} --num-docs #{@num_documents} " +
                  "--cluster-field cluster_#{level} --selection #{selection} --target-fraction #{hit_ratio}",
                  values)
  end

end
