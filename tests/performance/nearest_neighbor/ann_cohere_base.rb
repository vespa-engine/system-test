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
# The data files in cohere-data/ are created with the parquet-vectors tools (extract_vectors.py, assign_clusters.py)
# from the .parquet files of the data set:
#   uv run parquetvectors/utils/extract_vectors.py wikipedia-2023-11-embed-multilingual-v3 docs.fvecs --num 1000000
#   uv run parquetvectors/utils/extract_vectors.py wikipedia-2023-11-embed-multilingual-v3 queries.fvecs --offset 1000000 --num 10000
#   uv run parquetvectors/utils/assign_clusters.py docs.fvecs clusters.ivecs --clusters 1000 --spherical --centroids centroids.fvecs
#
# The test can use any number of documents up to the number of vectors in docs.fvecs (the first vectors are used).
# The clusters selected for each query (as with assign_query_clusters.py --target-fraction) are computed by
# make_query_clusters.cpp during the test, taking only the fed documents into account.
# There should be enough clusters such that the smallest hit ratio is covered by several clusters, but not too many,
# as a query restricted to its clusters contains about (hit ratio * number of clusters) terms (e.g., 100 for 10% with 1000 clusters).
class AnnCohereBase < CommonSiftGistBase

  CORRELATION = "correlation"
  HIT_RATIO = "hit_ratio"

  NO_CORRELATION = "none"
  POSITIVE_CORRELATION = "positive"
  NEGATIVE_CORRELATION = "negative"
  CORRELATIONS = [NO_CORRELATION, POSITIVE_CORRELATION, NEGATIVE_CORRELATION]

  # Fraction of the documents that pass the filter
  HIT_RATIOS = [0.1, 0.05, 0.01, 0.005]

  # A document gets value v in the 'filter' field if (id % FILTER_VALUES_DENOMINATOR) >= v,
  # so the filter 'filter=v' has hit ratio (FILTER_VALUES_DENOMINATOR - v) / FILTER_VALUES_DENOMINATOR.
  FILTER_VALUES_DENOMINATOR = 1000

  HNSW_SETTINGS = [
    # Defaults (as in the rank profile)
    {:approximate_threshold => 0.05, :filter_first_threshold => 0.00, :filter_first_exploration => 0.3},
    # Always use HNSW, with the filter-first heuristic for hit ratios below 40%
    {:approximate_threshold => 0.00, :filter_first_threshold => 0.40, :filter_first_exploration => 0.3}
  ]

  def initialize(*args)
    super(*args)
    @data_path = "cohere-data/"
    @base_fvecs = @data_path + "docs.fvecs"
    @query_fvecs = @data_path + "queries.fvecs"
    @doc_clusters_ivecs = @data_path + "clusters.ivecs"
    @centroids_fvecs = @data_path + "centroids.fvecs"
    @dimensions = 1024

    @num_queries_for_benchmark = 1000
  end

  def run_cohere_filter_test(sd_dir, num_documents, num_queries_for_recall)
    deploy_app(create_app(sd_dir, 0.3))
    start

    compile_generators
    generate_vectors_for_recall(num_queries_for_recall)
    generate_query_clusters(num_documents, num_queries_for_recall)
    feed_cohere(num_documents, "#{num_documents}-docs")
    assert_hitcount("query=sddocname:test", num_documents)

    # Without filter
    query_and_benchmark(BRUTE_FORCE, 10, 0)
    run_target_hits_10_tests
    query_and_benchmark(BRUTE_FORCE, 100, 0)
    query_and_benchmark(HNSW, 100, 0)
    calc_recall_for_queries(100, 0)

    CORRELATIONS.each do |correlation|
      HIT_RATIOS.each do |hit_ratio|
        fancy_puts "Benchmarking and checking recall for correlation=#{correlation}, hit_ratio=#{hit_ratio}"
        query_and_benchmark_with_filter(BRUTE_FORCE, 100, correlation, hit_ratio, HNSW_SETTINGS.first)
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
    @container.execute("g++ -g -O3 -std=c++20 -o #{@container_tmp_bin_dir}/make_query_clusters #{selfdir}make_query_clusters.cpp")
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

  # Computes the closest and farthest clusters for each query vector and hit ratio on the container,
  # and keeps the clusters of the queries used for recall on localhost.
  def generate_query_clusters(num_documents, num_queries_for_recall)
    num_queries = [@num_queries_for_benchmark, num_queries_for_recall].max
    assert_enough_records(@container, @query_fvecs_container, vector_record_size, num_queries)
    centroids = nn_download_file(@centroids_fvecs, @container)
    doc_clusters = nn_download_file(@doc_clusters_ivecs, @container)
    assert_enough_records(@container, doc_clusters, 8, num_documents)

    @query_cluster_files = {}
    @query_clusters_for_recall = {}
    [POSITIVE_CORRELATION, NEGATIVE_CORRELATION].each do |correlation|
      mode = (correlation == POSITIVE_CORRELATION) ? "closest" : "farthest"
      HIT_RATIOS.each do |hit_ratio|
        file = dirs.tmpdir + "query_clusters.#{correlation}.hr#{hit_ratio}.ivecs"
        @container.execute("#{@container_tmp_bin_dir}/make_query_clusters #{@query_fvecs_container} #{centroids} #{doc_clusters} " +
                           "#{@dimensions} #{num_queries} #{num_documents} #{hit_ratio} #{mode} > #{file}")
        @query_cluster_files[[correlation, hit_ratio]] = file

        local_file = dirs.tmpdir + "local_query_clusters.#{correlation}.hr#{hit_ratio}.ivecs"
        find_and_copy_to_localhost(file, local_file)
        @query_clusters_for_recall[[correlation, hit_ratio]] = read_ivecs(local_file, num_queries_for_recall)
      end
    end
  end

  # Reads the first num_records records (int32 length n followed by n int32 values) of an .ivecs file.
  def read_ivecs(file, num_records)
    data = File.binread(file).unpack("l<*")
    records = []
    pos = 0
    while records.size < num_records
      assert(pos < data.size, "#{file} contains less than #{num_records} records")
      n = data[pos]
      records.push(data[pos + 1, n])
      pos += n + 1
    end
    records
  end

  def feed_cohere(num_documents, label)
    profiler_start
    base_fvecs_local = nn_download_file(@base_fvecs, vespa.adminserver)
    doc_clusters_local = nn_download_file(@doc_clusters_ivecs, vespa.adminserver)
    assert_enough_records(vespa.adminserver, base_fvecs_local, vector_record_size, num_documents)
    filter_values = HIT_RATIOS.map { |hit_ratio| filter_value(hit_ratio) }
    command = "#{@adminserver_tmp_bin_dir}/make_clustered_docs #{base_fvecs_local} #{doc_clusters_local} cluster " +
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
    [parameter_filler(CORRELATION, correlation), parameter_filler(HIT_RATIO, hit_ratio)]
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
      @container.execute("#{@container_tmp_bin_dir}/make_clustered_queries #{@query_fvecs_container} " +
                         "#{@query_cluster_files[[correlation, hit_ratio]]} cluster #{common_args} > #{query_file}")
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
    end
    calc_recall_for_queries(target_hits, 0, params)
  end

end
