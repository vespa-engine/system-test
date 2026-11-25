# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor_new/cohere/cohere_base'

# Tests nearest neighbor search (HNSW) over the Cohere embeddings with filters that are
#   uncorrelated: on the field 'filter' (by document id), not correlated with the query vector
#   positive:     'cluster_<level> in (...)', restricted to the clusters closest to the query vector
#   negative:     'cluster_<level> in (...)', restricted to the clusters farthest from the query vector
# for different hit ratios (fraction of the documents passing the filter). The schema needs the array<int> field 'filter'
# and the int fields cluster_<level> (see cohere/schemas/filtered/).
#
# make_correlated_filtered_queries selects the closest or farthest clusters (from ranked_<level>.ivecs) of each query vector until they
# contain the target fraction of the fed documents, such that the hit ratio is correct for any number of documents.
# A query restricted to its clusters contains about (hit ratio * number of clusters) terms, so each hit ratio uses the
# cluster level that gives about 5 to 25 clusters per query (see CohereBase.cluster_level).
class AnnCohereFilteredPerfTest < CohereBase

  UNCORRELATED = "uncorrelated"
  POSITIVE = "positive"
  NEGATIVE = "negative"
  CORRELATIONS = [UNCORRELATED, POSITIVE, NEGATIVE]

  def setup
    super
    set_owner("boeker")
    @num_documents = 2_000_000 # The first vectors of cohere/cohere-data/docs_*.fvecs (e.g., 10_000 for development)
    @num_queries_for_benchmark = 1000
    @num_queries_for_recall = 100 # e.g., 10 for development
    @hit_ratios = [0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.001]
    set_request_parameters({"summary" => "minimal",
                            "hits" => :target_hits,
                            "ranking.matching.approximateThreshold" => :approximate_threshold,
                            "ranking.matching.filterFirstThreshold" => :filter_first_threshold,
                            "ranking.matching.filterFirstExploration" => :filter_first_exploration})
  end

  def test_cohere_filtered
    settings = [
      # Always use HNSW, with the filter-first heuristic for hit ratios below 20%
      {:name => "hnsw", :target_hits => 100,
       :approximate_threshold => 0.00, :filter_first_threshold => 0.20, :filter_first_exploration => 0.01}
    ]

    set_label_format("%{name}-th%{target_hits}-%{correlation}-hr%{hit_ratio}-at%{approximate_threshold}" +
                     "-fft%{filter_first_threshold}-ffe%{filter_first_exploration}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) with filters that are not, positively, and negatively correlated with the query vector " +
                    "over Cohere Wikipedia embeddings (1024 dim)")
    run_filtered_test(schema: "filtered",
                      settings: settings)
  end

  def test_cohere_filtered_quantized
    settings = [
      # Always use HNSW, without the filter-first heuristic
      {:name => "hnsw-q4", :target_hits => 100, # 4-bit quantized vectors (see cohere/schemas/filtered_quantized/)
       :approximate_threshold => 0.00, :filter_first_threshold => 0.00, :filter_first_exploration => 0.01}
    ]

    set_label_format("%{name}-th%{target_hits}-%{correlation}-hr%{hit_ratio}-at%{approximate_threshold}")

    set_description("Test performance and recall of nearestNeighbor (hnsw) over 4-bit quantized vectors with filters that are not, positively, and negatively correlated with the query vector " +
                    "over Cohere Wikipedia embeddings (1024 dim)")
    run_filtered_test(schema: "filtered_quantized",
                      settings: settings,
                      nnr: {"exactField" => "embedding_f32"}) # Full-precision vectors as the exact ground truth
  end

  # schema: the schema in schemas/<schema>/test.sd
  # settings: the HNSW settings to benchmark, e.g., target hits, exploration, and filter-first threshold
  # nnr: additional NearestNeighborRecallSearcher parameters without the prefix 'nnr.', e.g., {"exactField" => "embedding_f32"}
  def run_filtered_test(schema:, settings:, nnr: {})
    setup_cohere_test(schema)
    clusters_fine, clusters_medium, clusters_coarse = download_cluster_files(vespa.adminserver)
    feed_documents("make_filtered_docs",
                   "--hit-ratios #{@hit_ratios.join(',')} " +
                   "--cluster-files #{clusters_fine},#{clusters_medium},#{clusters_coarse} " +
                   "--cluster-fields cluster_fine,cluster_medium,cluster_coarse")

    results = {} # setting => {[correlation, hit_ratio] => {:recall, :qps, :avg_ms, :p95_ms}}
    settings.each do |setting|
      results[setting] = {}
      CORRELATIONS.each do |correlation|
        @hit_ratios.each do |hit_ratio|
          values = {:approximate => true, :explore_hits => 0}.merge(setting).merge(
            {:correlation => correlation, :hit_ratio => hit_ratio})
          query_file = generate_queries(correlation, hit_ratio, values)
          results[setting][[correlation, hit_ratio]] =
            benchmark_and_calc_recall(query_file, values, @num_queries_for_recall, nnr: nnr)
        end
      end
    end

    settings.each do |setting|
      print_results(results[setting], setting)
    end
  end

  # Prints a table of the results of one setting: one row per hit ratio, with the results for each correlation side by side
  # (recall, qps, avg ms, p95 ms). The title contains the number of documents and the setting.
  def print_results(results, setting)
    title = "Results for #{@num_documents} documents: " + setting.map { |key, value| "#{key} #{value}" }.join(", ")
    headers = [["", ""] + CORRELATIONS.flat_map { |correlation| [correlation, "", "", ""] },
               ["hit ratio", "level"] + CORRELATIONS.flat_map { ["recall", "qps", "avg ms", "p95 ms"] }]
    rows = @hit_ratios.map do |hit_ratio|
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

  # Generates the queries with a filter with the correlation and hit ratio for the benchmark, and returns the query file
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
