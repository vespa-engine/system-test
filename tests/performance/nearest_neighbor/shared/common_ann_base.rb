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

  # Uses a local copy of the file if it exists at selfdir + @local_data_dir + file_name,
  # where @local_data_dir is an optional sub-directory set by the test (e.g. "sift_gist/").
  def nn_download_file(file_name, vespa_node)
    local_file = selfdir + (@local_data_dir || "") + file_name
    if File.exist?(local_file)
      # Place the file in the test directory to avoid downloading during manual testing.
      puts "Using local file #{local_file}"
      return local_file
    end
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

  # Copies a file from the Vespa node that has it (e.g. the container) to localhost.
  def find_and_copy_to_localhost(remote_file, local_file)
    copied = false
    vespa.nodeproxies.each_value do |node|
      if node.file?(remote_file)
        node.copy_remote_file_to_local_file(remote_file, local_file)
        copied = true
        break
      end
    end

    # Make sure that we actually found the node proxy corresponding to the container and copied the file
    assert(copied)
  end

  # Returns the ranking.matching.* request parameters for the given params (with the defaults used in these tests).
  def matching_params_str(params)
    "&ranking.matching.approximateThreshold=#{params[:approximate_threshold] || 0.05}" +
    "&ranking.matching.filterFirstThreshold=#{params[:filter_first_threshold] || 0.0}" +
    "&ranking.matching.filterFirstExploration=#{params[:filter_first_exploration] || 0.3}" +
    "&ranking.matching.explorationSlack=#{params[:slack] || 0.0}" +
    "&ranking.matching.lazyFilter=#{params[:lazy_filter] || false}"
  end

  # Calculates and reports the recall of the given queries using NearestNeighborRecallSearcher.
  # The searcher runs each query as it is and with approximate=false (the exact ground truth), and compares the hits.
  #
  # queries: query URLs ('/search/?yql=...'), typically lines from an fbench query file.
  # target_hits: the number of hits that are compared.
  # params:
  #   :nnr - additional parameters to NearestNeighborRecallSearcher, e.g. {'exactField' => 'vec_f32'}.
  #   :approximate => false - the queries use exact search (used to measure the recall loss from quantization).
  #   The ranking.matching.* settings (see matching_params_str) and the remaining params are used in the report.
  def calc_recall(queries, target_hits, explore_hits, params = {})
    filter_percent = params[:filter_percent] || 0
    radius = params[:radius] || -1.0
    approximate_threshold = params[:approximate_threshold] || 0.05
    filter_first_threshold = params[:filter_first_threshold] || 0.0
    filter_first_exploration = params[:filter_first_exploration] || 0.3
    slack = params[:slack] || 0.0
    annotation = params[:annotation] || "none"
    lazy_filter = params[:lazy_filter] || false
    quantization_bits = params[:quantization_bits] || nil
    approximate = params.fetch(:approximate, true)
    nnr_params = params[:nnr] || {}

    request_params = matching_params_str(params) + "&nnr.enable=true" +
                     nnr_params.map { |key, value| "&nnr.#{key}=#{value}" }.join
    puts "calc_recall: target_hits=#{target_hits}, explore_hits=#{explore_hits}, queries.size=#{queries.size}, " +
         "approximate=#{approximate}, request_params=#{request_params}"

    result = RecallResult.new(target_hits)
    num_threads = 5
    batch_size = (queries.size.to_f / num_threads.to_f).ceil
    batches = queries.each_slice(batch_size).to_a
    assert_equal(batches.size, num_threads)
    threads = batches.map do |batch|
      Thread.new(batch) do |batch_queries|
        batch_queries.each do |query|
          result.add(calc_recall_in_searcher(query + request_params))
        end
      end
    end
    threads.each(&:join)

    puts "recall: avg=#{result.avg}, median=#{result.median}, min=#{result.min}, max=#{result.max}, size=#{result.size}, samples_sorted=[#{result.samples.sort.join(',')}], samples=[#{result.samples.join(',')}]"
    radius_str = (radius >= 0.0) ? "-r#{radius}" : ""
    lazy_str = lazy_filter ? "-lazy" : ""
    label = params[:label] || "#{approximate ? 'hnsw' : 'exact'}-th#{target_hits}" +
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

  def calc_recall_in_searcher(query)
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
