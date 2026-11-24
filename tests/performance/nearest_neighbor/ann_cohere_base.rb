# Copyright Vespa.ai. All rights reserved.

require 'performance/nearest_neighbor/common_sift_gist_base'

# Tests nearest neighbor search with filters over Cohere embeddings (1024 dimensions, normalized) of Wikipedia passages
# (https://huggingface.co/datasets/Cohere/wikipedia-2023-11-embed-multilingual-v3).
#
# The filters have different hit ratios (fraction of documents passing the filter) and are
#   - not correlated with the query vector (filter on the document id via the 'filter' field),
#   - positively correlated with the query vector (restricted to the clusters closest to the query vector),
#   - negatively correlated with the query vector (restricted to the clusters farthest from the query vector).
#
# The test uses the following files in cohere-data/ (all values little-endian):
#   docs.fvecs             1M document vectors                                   [per vector: int32 1024, 1024 float32]
#   queries.fvecs          10k query vectors (not among the document vectors)     [per vector: int32 1024, 1024 float32]
#   clusters_<level>.ivecs the cluster of each document at the level              [per document: int32 1, int32 cluster]
#   ranked_<level>.ivecs   all clusters of the level for each query vector,       [per query: int32 n, n int32 clusters]
#                          ordered from closest to farthest
# The documents are clustered (spherical k-means) at the levels fine (1000 clusters), medium (200), and coarse (50).
# If files are missing in cohere-data/, the test extracts them from cohere-data/cohere-data.tar.gz (containing the folder
# cohere-data/ with all files), which is downloaded from the nearest-neighbor S3 folder if not present, i.e., from
# https://data.vespa-cloud.com/tests/performance/nearest-neighbor/cohere-data/cohere-data.tar.gz.
#
# The test can use any number of documents up to the number of vectors in docs.fvecs (the first vectors are used).
# make_clustered_queries selects the closest or farthest clusters (from ranked_<level>.ivecs) of each query vector until they
# contain the target fraction of the fed documents, such that the hit ratio is correct for any number of documents.
# A query restricted to its clusters contains about (hit ratio * number of clusters) terms, so each hit ratio uses the
# cluster level that gives about 5 to 25 clusters per query (see HIT_RATIO_LEVELS).
class AnnCohereBase < CommonSiftGistBase

  CORRELATION = "correlation"
  HIT_RATIO = "hit_ratio"

  NO_CORRELATION = "none"
  POSITIVE_CORRELATION = "positive"
  NEGATIVE_CORRELATION = "negative"
  CORRELATIONS = [NO_CORRELATION, POSITIVE_CORRELATION, NEGATIVE_CORRELATION]

  CLUSTER_LEVEL = "cluster_level"

  # Cluster levels of the documents (with 1000, 200, and 50 clusters), each in the field cluster_<level>
  CLUSTER_LEVELS = ["fine", "medium", "coarse"]

  # Fraction of the documents that pass the filter => cluster level used for the correlated filters with this hit ratio
  # The level is chosen such that the queries contain about 5 to 25 clusters (hit ratio * number of clusters of the level),
  # which keeps the queries small while the selected clusters contain close to the target fraction of the documents.
  HIT_RATIO_LEVELS = {0.5 => "coarse", 0.3 => "coarse", 0.2 => "coarse",
                      0.1 => "medium", 0.05 => "medium",
                      0.02 => "fine", 0.01 => "fine", 0.005 => "fine",
                      # Only about 1 to 4 clusters per query, so the selected clusters can contain several times the target fraction
                      0.001 => "fine"}
  HIT_RATIOS = HIT_RATIO_LEVELS.keys

  # A document gets value v in the 'filter' field if (id % FILTER_VALUES_DENOMINATOR) >= v,
  # so the filter 'filter=v' has hit ratio (FILTER_VALUES_DENOMINATOR - v) / FILTER_VALUES_DENOMINATOR.
  FILTER_VALUES_DENOMINATOR = 1000

  HNSW_SETTINGS = [
    # Always use HNSW, without the filter-first heuristic
    {:approximate_threshold => 0.00, :filter_first_threshold => 0.00, :filter_first_exploration => 0.3}
  ]

  def initialize(*args)
    super(*args)
    @data_path = "cohere-data/"
    @data_archive = @data_path + "cohere-data.tar.gz" # Contains all data files in the folder cohere-data/
    @base_fvecs = @data_path + "docs.fvecs"
    @query_fvecs = @data_path + "queries.fvecs"
    @doc_clusters_ivecs = CLUSTER_LEVELS.to_h { |level| [level, @data_path + "clusters_#{level}.ivecs"] }
    @ranked_query_clusters_ivecs = CLUSTER_LEVELS.to_h { |level| [level, @data_path + "ranked_#{level}.ivecs"] }
    @dimensions = 1024

    @num_queries_for_benchmark = 1000
  end

  def run_cohere_filter_test(sd_dir, num_documents, num_queries_for_recall)
    @num_documents = num_documents
    deploy_app(create_app(sd_dir, 0.3))
    start

    compile_generators
    generate_vectors_for_recall(num_queries_for_recall)
    generate_query_clusters(num_queries_for_recall)
    feed_cohere(num_documents, "#{num_documents}-docs")
    assert_hitcount("query=sddocname:test", num_documents)

    CORRELATIONS.each do |correlation|
      HIT_RATIOS.each do |hit_ratio|
        fancy_puts "Benchmarking and checking recall for correlation=#{correlation}, hit_ratio=#{hit_ratio}"
        HNSW_SETTINGS.each do |settings|
          query_and_benchmark_with_filter(HNSW, 100, correlation, hit_ratio, settings)
          calc_recall_with_filter(100, correlation, hit_ratio, settings)
        end
      end
    end
  end

  def compile_generators
    super
    vespa.adminserver.execute("g++ -g -O3 -std=c++20 -o #{@adminserver_tmp_bin_dir}/make_clustered_docs #{selfdir}make_clustered_docs.cpp")
    @container.execute("g++ -g -O3 -std=c++20 -o #{@container_tmp_bin_dir}/make_clustered_queries #{selfdir}make_clustered_queries.cpp")
  end

  def filter_value(hit_ratio)
    FILTER_VALUES_DENOMINATOR - (hit_ratio * FILTER_VALUES_DENOMINATOR).round
  end

  def assert_enough_records(node, file, record_size, num_needed)
    num_available = node.execute("stat -L -c %s #{file}").strip.to_i / record_size
    assert(num_available >= num_needed, "#{file} contains #{num_available} records, but #{num_needed} are needed")
  end

  def vector_record_size
    4 + 4 * @dimensions
  end

  # Returns the path of a data file on the node. Uses the file in the test directory if present. Otherwise, extracts the
  # archive with all data files on the node, taking the archive from the test directory if present, or downloading it.
  def nn_download_file(file_name, vespa_node)
    if !file_name.start_with?(@data_path) || file_name == @data_archive || File.exist?(selfdir + file_name)
      return super(file_name, vespa_node)
    end
    extracted_data_dir(vespa_node) + file_name
  end

  # Extracts the data archive on the node (once) and returns the directory containing the folder @data_path.
  def extracted_data_dir(vespa_node)
    extract_dir = dirs.tmpdir + "extracted/"
    marker = extract_dir + @data_path + ".extracted"
    if vespa_node.file?(marker)
      puts "Using already extracted data in #{extract_dir + @data_path}"
    else
      puts "Data file(s) missing in #{selfdir + @data_path}, extracting #{@data_archive}"
      archive = nn_download_file(@data_archive, vespa_node)
      vespa_node.execute("mkdir -p #{extract_dir} && tar -xzf #{archive} -C #{extract_dir} && touch #{marker}")
    end
    extract_dir
  end

  def cluster_field(level)
    "cluster_#{level}"
  end

  # Downloads the files needed by make_clustered_queries to the container, and keeps the clusters selected
  # for the queries used for recall on localhost.
  def generate_query_clusters(num_queries_for_recall)
    num_queries = [@num_queries_for_benchmark, num_queries_for_recall].max
    assert_enough_records(@container, @query_fvecs_container, vector_record_size, num_queries)
    @ranked_query_clusters_container = {}
    @doc_clusters_container = {}
    HIT_RATIO_LEVELS.values.uniq.each do |level|
      @ranked_query_clusters_container[level] = nn_download_file(@ranked_query_clusters_ivecs[level], @container)
      @doc_clusters_container[level] = nn_download_file(@doc_clusters_ivecs[level], @container)
    end

    @query_clusters_for_recall = {}
    [POSITIVE_CORRELATION, NEGATIVE_CORRELATION].each do |correlation|
      HIT_RATIOS.each do |hit_ratio|
        # Generate queries only for the clusters
        file = dirs.tmpdir + "query_clusters.#{correlation}.hr#{hit_ratio}.txt"
        @container.execute("#{make_clustered_queries_command(correlation, hit_ratio)} #{@dimensions} #{num_queries_for_recall} " +
                           "vec_m16 > #{file}")
        local_file = dirs.tmpdir + "local_query_clusters.#{correlation}.hr#{hit_ratio}.txt"
        find_and_copy_to_localhost(file, local_file)
        @query_clusters_for_recall[[correlation, hit_ratio]] =
          parse_query_clusters(local_file, num_queries_for_recall, cluster_field(HIT_RATIO_LEVELS[hit_ratio]))
      end
    end
  end

  def make_clustered_queries_command(correlation, hit_ratio)
    level = HIT_RATIO_LEVELS[hit_ratio]
    selection = (correlation == POSITIVE_CORRELATION) ? "closest" : "farthest"
    "#{@container_tmp_bin_dir}/make_clustered_queries #{@query_fvecs_container} #{@ranked_query_clusters_container[level]} " +
    "#{@doc_clusters_container[level]} #{@num_documents} #{cluster_field(level)} #{selection} #{hit_ratio}"
  end

  # Extracts the clusters from "<field> in (c_1,...,c_n)" in each query of a query file.
  def parse_query_clusters(file, num_queries, field)
    clusters = File.readlines(file).map do |query|
      match = query.match(/%20#{field}%20in%20\(([0-9,]+)\)/)
      assert(match, "No clusters for #{field} found in query '#{query[0, 200]}...'")
      match[1].split(",").map(&:to_i)
    end
    assert_equal(num_queries, clusters.size)
    clusters
  end

  def feed_cohere(num_documents, label)
    profiler_start
    base_fvecs_local = nn_download_file(@base_fvecs, vespa.adminserver)
    doc_clusters_local = CLUSTER_LEVELS.map { |level| nn_download_file(@doc_clusters_ivecs[level], vespa.adminserver) }
    assert_enough_records(vespa.adminserver, base_fvecs_local, vector_record_size, num_documents)
    filter_values = HIT_RATIOS.map { |hit_ratio| filter_value(hit_ratio) }
    command = "#{@adminserver_tmp_bin_dir}/make_clustered_docs #{base_fvecs_local} #{doc_clusters_local.join(',')} " +
              "#{CLUSTER_LEVELS.map { |level| cluster_field(level) }.join(',')} " +
              "#{@dimensions} put 0 0 #{num_documents} '[#{filter_values.join(',')}]' #{FILTER_VALUES_DENOMINATOR} " +
              "'[0.0,-1.0]' '[0.0,-1.0]' false vec_m16"
    run_stream_feeder(command, [parameter_filler(TYPE, "feed"), parameter_filler(LABEL, label)])
    profiler_report("feed")
    print_nni_stats("test", "vec_m16")
  end

  def filter_label(algorithm, target_hits, correlation, hit_ratio, settings)
    "#{algorithm}-th#{target_hits}-#{correlation}-hr#{hit_ratio}-at#{settings[:approximate_threshold]}" +
    "-fft#{settings[:filter_first_threshold]}-ffe#{settings[:filter_first_exploration]}"
  end

  def filter_fillers(correlation, hit_ratio)
    level = (correlation == NO_CORRELATION) ? "none" : HIT_RATIO_LEVELS[hit_ratio]
    [parameter_filler(CORRELATION, correlation), parameter_filler(HIT_RATIO, hit_ratio), parameter_filler(CLUSTER_LEVEL, level)]
  end

  def query_and_benchmark_with_filter(algorithm, target_hits, correlation, hit_ratio, settings)
    approximate = (algorithm == HNSW) ? "true" : "false"
    label = filter_label(algorithm, target_hits, correlation, hit_ratio, settings)
    query_file = dirs.tmpdir + "queries.#{label}.txt"
    common_args = "#{@dimensions} #{@num_queries_for_benchmark} vec_m16 #{approximate} #{target_hits} 0"
    if correlation == NO_CORRELATION
      @container.execute("#{@container_tmp_bin_dir}/make_queries #{@query_fvecs_container} #{common_args} " +
                         "#{filter_value(hit_ratio)} > #{query_file}")
    else
      @container.execute("#{make_clustered_queries_command(correlation, hit_ratio)} #{common_args} > #{query_file}")
    end
    puts "Generated on container: #{query_file}"

    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(TYPE, "query_filter"),
               parameter_filler(LABEL, label),
               parameter_filler(ALGORITHM, algorithm),
               parameter_filler(TARGET_HITS, target_hits),
               parameter_filler(EXPLORE_HITS, 0),
               parameter_filler(APPROXIMATE_THRESHOLD, settings[:approximate_threshold]),
               parameter_filler(FILTER_FIRST_THRESHOLD, settings[:filter_first_threshold]),
               parameter_filler(FILTER_FIRST_EXPLORATION, settings[:filter_first_exploration]),
               parameter_filler(CLIENTS, 1)] + filter_fillers(correlation, hit_ratio)
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => 1,
                 :append_str => "&summary=minimal&hits=#{target_hits}&ranking=default" +
                                "&ranking.matching.approximateThreshold=#{settings[:approximate_threshold]}" +
                                "&ranking.matching.filterFirstThreshold=#{settings[:filter_first_threshold]}" +
                                "&ranking.matching.filterFirstExploration=#{settings[:filter_first_exploration]}",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -10 #{result_file}")
  end

  def calc_recall_with_filter(target_hits, correlation, hit_ratio, settings)
    params = settings.merge({:label => filter_label(HNSW, target_hits, correlation, hit_ratio, settings),
                             :extra_fillers => filter_fillers(correlation, hit_ratio)})
    if correlation == NO_CORRELATION
      params[:filter_percent] = filter_value(hit_ratio)
    else
      params[:query_clusters] = @query_clusters_for_recall[[correlation, hit_ratio]]
      params[:cluster_field] = cluster_field(HIT_RATIO_LEVELS[hit_ratio])
    end
    calc_recall_for_queries(target_hits, 0, params)
  end

end
