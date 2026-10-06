# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class CommonAnnBaseTest < PerformanceTest

  TYPE = "type"
  LABEL = "label"
  ALGORITHM = "algorithm"
  TARGET_HITS = "target_hits"
  EXPLORE_HITS = "explore_hits"
  FILTER_PERCENT = "filter_percent"
  RADIUS = "radius"
  LAZY_FILTER = "lazy_filter"
  APPROXIMATE_THRESHOLD = "approximate_threshold"
  FILTER_FIRST_THRESHOLD = "filter_first_threshold"
  FILTER_FIRST_EXPLORATION = "filter_first_exploration"
  SLACK = "slack"
  HNSW = "hnsw"
  BRUTE_FORCE = "brute_force"
  RECALL_AVG = "recall.avg"
  RECALL_MEDIAN = "recall.median"
  CLIENTS = "clients"
  THREADS_PER_SEARCH = "threads_per_search"
  ANNOTATION = "annotation"
  NNI_UNREACHABLE = "nni.unreachable"

  def start
    super
    node = vespa.container.values.first
    puts "Getting some hardware details from node #{node}"
    node.execute('numactl --show', :exceptiononfailure => false)
    node.execute('lscpu', :exceptiononfailure => false)
  end

  # Takes an application package directory and a single (relative) SD file name within
  # and returns a directory path that contains a copy of the application package but
  # with the contents of the SD file rewritten based on `substitutions`.
  #
  # Example:
  # If the SD file contains "hello %{FOO}!" and `substitutions` is {'FOO' => 'world'},
  # the resulting SD file contents will be "hello world!".
  #
  # No attempt is made to detect non-matching substitution patterns in the file, so use
  # with care. Must only be used with trusted input arguments.
  def copy_app_with_templated_sd_file(src_app_dir, sd_file, substitutions)
    unless File.exist?(src_app_dir + '/' + sd_file)
      raise "expected #{sd_file} to exist in directory #{src_app_dir}"
    end
    gen_dir = dirs.tmpdir + 'gen_app_dir'
    FileUtils.cp_r(src_app_dir, gen_dir)
    # We have sed at home
    sd_data = File.read(src_app_dir + '/' + sd_file)
    substitutions.each_pair do |from, to|
      sd_data.gsub!(/%\{#{from}\}/, to.to_s)
    end
    File.write(gen_dir + '/' + sd_file, sd_data)
    gen_dir
  end

  def nn_download_file(file_name, vespa_node)
    puts "Trying to download from NN s3: #{file_name}"
    download_file_from_s3(file_name, vespa_node, 'nearest-neighbor')
  end

  def feed_and_benchmark(feed_file, label, doc_type = "test", tensor = "vec_m16", include_nni_stats = true)
    profiler_start
    node_file = nn_download_file(feed_file, vespa.adminserver)
    run_feeder(node_file, [parameter_filler(TYPE, "feed"), parameter_filler(LABEL, label)], :localfile => true)
    vespa.adminserver.execute("ls -ld #{node_file} #{selfdir}", :exceptiononfailure => false)
    profiler_report("feed")
    print_nni_stats(doc_type, tensor) if include_nni_stats
  end

  def print_nni_stats(doc_type, tensor, annotation = "none")
    stats = get_nni_stats(doc_type, tensor)
    write_report([parameter_filler(TYPE, "nni"),
                  parameter_filler(ANNOTATION, annotation),
                  metric_filler(NNI_UNREACHABLE, calc_nni_unreachable(stats))])
    puts "Nearest neighbor index statistics for '#{tensor}': #{stats}"
  end

  def calc_nni_unreachable(stats)
    stats["reachability_analysis"]["nodes_not_found_pct"].to_f
  end

  def get_nni_stats(doc_type, tensor)
    uri = "/documentdb/#{doc_type}/subdb/ready/attribute/#{tensor}/tensor/nearest_neighbor_index"
    stats = vespa.search["search"].first.get_state_v1_custom_component(uri)
    puts "stats=#{stats}"
    stats
  end

  def prepare_queries_for_recall
    @local_query_vectors = dirs.tmpdir + "query_vectors.txt"
    fetch_file_to_localhost(@query_vectors, @local_query_vectors)
  end

  QueryDatum = Struct.new(:vector, :latitude, :longitude)

  def calc_recall_for_queries(target_hits, explore_hits, params = {})
    filter_percent = params[:filter_percent] || 0
    radius = params[:radius] || -1.0
    approximate_threshold = params[:approximate_threshold] || 0.05
    filter_first_threshold = params[:filter_first_threshold] || 0.0
    filter_first_exploration = params[:filter_first_exploration] || 0.3
    slack = params[:slack] || 0.0
    doc_type = params[:doc_type] || "test"
    doc_tensor = params[:doc_tensor] || "vec_m16"
    query_tensor = params[:query_tensor] || "q_vec"
    annotation = params[:annotation] || "none"
    lazy_filter = params[:lazy_filter] || false
    exact_match_tensor = params[:exact_match_tensor] || doc_tensor
    quantization_bits = params[:quantization_bits] || nil
    exact_match_rank_profile = params[:exact_match_rank_profile] || 'default'
    approx_match_rank_profile = params[:approx_match_rank_profile] || 'default'
    use_exact_for_approx_match_phase = params[:use_exact_for_approx_match_phase] || false

    puts "calc_recall_for_queries: target_hits=#{target_hits}, explore_hits=#{explore_hits}, " +
         "filter_percent=#{filter_percent}, approximate_threshold=#{approximate_threshold}, " +
         "filter_first_threshold=#{filter_first_threshold}, filter_first_exploration=#{filter_first_exploration}, " +
         "slack=#{slack}, doc_type=#{doc_type}, doc_tensor=#{doc_tensor}, query_tensor=#{query_tensor}, " +
         "quantization_bits=#{quantization_bits.nil? ? 'N/A' : quantization_bits}, " +
         "exact_match_tensor=#{exact_match_tensor.nil? ? "N/A" : exact_match_tensor}, " +
         "exact_match_rank_profile=#{exact_match_rank_profile}, " +
         "approx_match_rank_profile=#{approx_match_rank_profile}, " +
         "use_exact_for_approx_match_phase=#{use_exact_for_approx_match_phase}"
    result = RecallResult.new(target_hits)

    query_data = []
    num_threads = 5
    File.open(@local_query_vectors, "r").each do |vector|
      vector = vector.strip

      qd = QueryDatum.new
      qd.vector = vector.strip
      qd.latitude = 0.0
      qd.longitude = 0.0
      query_data.push(qd)
    end

    if not @local_locations.nil? and File.exist?(@local_locations)
      num = 0
      File.open(@local_locations, "r").each do |location|
        latlng = location.strip.split(",")
        assert_equal(2, latlng.length)

        assert(num < query_data.length)
        query_data[num].latitude = latlng[0]
        query_data[num].longitude = latlng[1]

        num += 1
      end
      assert_equal(query_data.length, num)
    end

    batch_size = (query_data.size.to_f / num_threads.to_f).ceil
    batches = query_data.each_slice(batch_size).to_a
    puts "calc_recall_for_queries: query_data.size=#{query_data.size}, num_threads=#{num_threads}, " +
         "batch_size=#{batch_size}, batches.size=#{batches.size}"
    assert_equal(batches.size, num_threads)
    threads = []
    for i in 0...num_threads
      threads << Thread.new(batches[i]) do |batch|
        calc_recall_for_query_batch(target_hits, explore_hits, filter_percent, radius, approximate_threshold,
                                    filter_first_threshold, filter_first_exploration, slack, lazy_filter, batch,
                                    result, doc_type, doc_tensor, query_tensor, exact_match_tensor,
                                    exact_match_rank_profile, approx_match_rank_profile,
                                    use_exact_for_approx_match_phase)
      end
    end
    threads.each(&:join)
    puts "recall: avg=#{result.avg}, median=#{result.median}, min=#{result.min}, max=#{result.max}, size=#{result.size}, samples_sorted=[#{result.samples.sort.join(',')}], samples=[#{result.samples.join(',')}]"
    radius_str = (radius >= 0.0) ? "-r#{radius}" : ""
    lazy_str = lazy_filter ? "-lazy" : ""
    label = params[:label] || "#{use_exact_for_approx_match_phase ? 'exact' : 'hnsw'}-th#{target_hits}" +
            "-eh#{explore_hits}-f#{filter_percent}#{radius_str}#{lazy_str}-at#{approximate_threshold}" +
            "-fft#{filter_first_threshold}-ffe#{filter_first_exploration}-sl#{slack}"
    # Put quantization level first, if present, since we consider it an Important Detail(tm)
    label = "q#{quantization_bits}-#{label}" unless quantization_bits.nil?
    write_report([parameter_filler(TYPE, "recall"),
                  parameter_filler(LABEL, label),
                  parameter_filler(TARGET_HITS, target_hits),
                  parameter_filler(EXPLORE_HITS, explore_hits),
                  parameter_filler(FILTER_PERCENT, filter_percent),
                  parameter_filler(RADIUS, radius),
                  parameter_filler(LAZY_FILTER, lazy_filter),
                  parameter_filler(APPROXIMATE_THRESHOLD, approximate_threshold),
                  parameter_filler(FILTER_FIRST_THRESHOLD, filter_first_threshold),
                  parameter_filler(FILTER_FIRST_EXPLORATION, filter_first_exploration),
                  parameter_filler(SLACK, slack),
                  parameter_filler(ANNOTATION, annotation),
                  metric_filler(RECALL_AVG, result.avg),
                  metric_filler(RECALL_MEDIAN, result.median)])
  end

  def calc_recall_for_query_batch(target_hits, explore_hits, filter_percent, radius, approximate_threshold,
                                  filter_first_threshold, filter_first_exploration, slack, lazy_filter, batch,
                                  result, doc_type, doc_tensor, query_tensor, exact_match_tensor,
                                  exact_match_rank_profile, approx_match_rank_profile,
                                  use_exact_for_approx_match_phase)
    batch.each do |datum|
      raw_recall = calc_recall_in_searcher(target_hits, explore_hits, filter_percent, radius,
                                           approximate_threshold, filter_first_threshold, filter_first_exploration,
                                           slack, lazy_filter, datum, doc_type, doc_tensor, query_tensor,
                                           exact_match_tensor, exact_match_rank_profile, approx_match_rank_profile,
                                           use_exact_for_approx_match_phase)
      result.add(raw_recall)
    end
  end

  def fetch_file_to_localhost(remote_file, local_file)
    proxy_node = @vespa.nodeproxies.values.first
    proxy_file = nn_download_file(remote_file, proxy_node)
    proxy_node.copy_remote_file_to_local_file(proxy_file, local_file)
  end

  def calc_recall_in_searcher(target_hits, explore_hits, filter_percent, radius, approximate_threshold,
                              filter_first_threshold, filter_first_exploration, slack, lazy_filter, datum,
                              doc_type, doc_tensor, query_tensor, exact_match_tensor, exact_match_rank_profile,
                              approx_match_rank_profile, use_exact_for_approx_match_phase)
    query = get_query_for_recall_searcher(target_hits, explore_hits, filter_percent, radius, approximate_threshold,
                                          filter_first_threshold, filter_first_exploration, slack, lazy_filter,
                                          datum, doc_type, doc_tensor, query_tensor, exact_match_tensor,
                                          exact_match_rank_profile, approx_match_rank_profile,
                                          use_exact_for_approx_match_phase)
    result = search_with_timeout(20, query)
    assert_hitcount(result, 1)
    hit = result.hit[0]
    recall = hit.field["recall"]
    if recall == nil
      error = hit.field["error"]
      assert(false, "Error while calculating recall for query='#{query}': #{error}")
    end
    recall.to_i
  end

  def get_query_for_recall_searcher(target_hits, explore_hits, filter_percent, radius, approximate_threshold,
                                    filter_first_threshold, filter_first_exploration, slack, lazy_filter, datum,
                                    doc_type, doc_tensor, query_tensor, exact_match_tensor, exact_match_rank_profile,
                                    approx_match_rank_profile, use_exact_for_approx_match_phase)
    "query=sddocname:#{doc_type}&summary=minimal&ranking.features.query(#{query_tensor})=#{datum.vector}" +
    "&nnr.enable=true&nnr.docTensor=#{doc_tensor}&nnr.targetHits=#{target_hits}&nnr.exploreHits=#{explore_hits}&nnr.filterPercent=#{filter_percent}" +
    "&nnr.approximateThreshold=#{approximate_threshold}&nnr.filterFirstThreshold=#{filter_first_threshold}&nnr.filterFirstExploration=#{filter_first_exploration}" +
    "&nnr.slack=#{slack}&nnr.queryTensor=#{query_tensor}&nnr.radius=#{radius}&nnr.latitude=#{datum.latitude}&nnr.longitude=#{datum.longitude}&nnr.lazyFilter=#{lazy_filter}" +
    "&nnr.approxMatchRankProfile=#{approx_match_rank_profile}" +
    "&nnr.exactMatchRankProfile=#{exact_match_rank_profile}" +
    "&nnr.exactMatchTensor=#{exact_match_tensor}" +
    "&nnr.useExactForApproxMatchPhase=#{use_exact_for_approx_match_phase}"
  end

  class RecallResult
    def initialize(target_hits)
      @mutex = Mutex.new
      @samples = []
      @sum = 0
      @cnt = 0
      @min = target_hits
      @max = 0
      @percent_scale = 100.0 / target_hits
    end

    def add(recall)
      @mutex.synchronize do
        @samples.push(recall)
        @sum += recall
        @cnt += 1
        @min = recall if recall < @min
        @max = recall if recall > @max
      end
    end

    def avg
      (@sum.to_f / @cnt.to_f) * @percent_scale
    end

    def median
      sorted = @samples.sort
      len = sorted.length
      raw = (sorted[(len - 1)/2] + sorted[len / 2]) / 2.0
      raw * @percent_scale
    end

    def min
      @min * @percent_scale
    end

    def max
      @max * @percent_scale
    end

    def size
      @samples.length
    end

    def samples
      @samples
    end
  end

end
