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
  HNSW = "hnsw"
  BRUTE_FORCE = "brute_force"
  RECALL_AVG = "recall.avg"
  RECALL_MEDIAN = "recall.median"
  CLIENTS = "clients"
  THREADS_PER_SEARCH = "threads_per_search"
  NNI_UNREACHABLE = "nni.unreachable"

  def nn_download_file(file_name, vespa_node)
    puts "Trying to download from NN s3: #{file_name}"
    download_file_from_s3(file_name, vespa_node, 'nearest-neighbor')
  end

  def feed_and_benchmark(feed_file, label, doc_type = "test", tensor = "vec_m16")
    profiler_start
    node_file = nn_download_file(feed_file, vespa.adminserver)
    run_feeder(node_file, [parameter_filler(TYPE, "feed"), parameter_filler(LABEL, label)], :localfile => true)
    vespa.adminserver.execute("ls -ld #{node_file} #{selfdir}", :exceptiononfailure => false)
    profiler_report("feed")
    print_nni_stats(doc_type, tensor)
  end

  def print_nni_stats(doc_type, tensor)
    stats = get_nni_stats(doc_type, tensor)
    write_report([parameter_filler(TYPE, "nni"),
                  metric_filler(NNI_UNREACHABLE, calc_nni_unreachable(stats))])
    puts "Nearest neighbor index statistics for '#{tensor}': #{stats}"
  end

  def calc_nni_unreachable(stats)
    valid_nodes = stats["valid_nodes"].to_f
    unreachable_nodes = valid_nodes
    if stats.key?("unreachable_nodes")
      unreachable_nodes = stats["unreachable_nodes"].to_f
    elsif stats.key?("unreachable_nodes_incomplete_count")
      unreachable_nodes = stats["unreachable_nodes_incomplete_count"].to_f
    end
    (unreachable_nodes / valid_nodes) * 100.0
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

  def calc_recall_for_queries(target_hits, explore_hits, doc_type = "test", doc_tensor = "vec_m16", query_tensor = "q_vec")
    puts "calc_recall_for_queries: target_hits=#{target_hits}, explore_hits=#{explore_hits}, doc_type=#{doc_type}, doc_tensor=#{doc_tensor}, query_tensor=#{query_tensor}"
    result = RecallResult.new(target_hits)
    vectors = []
    num_threads = 5
    File.open(@local_query_vectors, "r").each do |vector|
      vector = vector.strip
      vectors.push(vector)
    end
    batch_size = (vectors.size.to_f / num_threads.to_f).ceil
    batches = vectors.each_slice(batch_size).to_a
    puts "calc_recall_for_queries: vectors.size=#{vectors.size}, num_threads=#{num_threads}, batch_size=#{batch_size}, batches.size=#{batches.size}"
    assert_equal(batches.size, num_threads)
    threads = []
    for i in 0...num_threads
      threads << Thread.new(batches[i]) do |batch|
        calc_recall_for_query_batch(target_hits, explore_hits, batch, result, doc_type, doc_tensor, query_tensor)
      end
    end
    threads.each(&:join)
    puts "recall: avg=#{result.avg}, median=#{result.median}, min=#{result.min}, max=#{result.max}, size=#{result.size}, samples_sorted=[#{result.samples.sort.join(',')}], samples=[#{result.samples.join(',')}]"
    label = "th#{target_hits}-eh#{explore_hits}"
    write_report([parameter_filler(TYPE, "recall"),
                  parameter_filler(LABEL, label),
                  parameter_filler(TARGET_HITS, target_hits),
                  parameter_filler(EXPLORE_HITS, explore_hits),
                  metric_filler(RECALL_AVG, result.avg),
                  metric_filler(RECALL_MEDIAN, result.median)])
  end

  def calc_recall_for_query_batch(target_hits, explore_hits, vectors, result, doc_type, doc_tensor, query_tensor)
    vectors.each do |vector|
      raw_recall = calc_recall_in_searcher(target_hits, explore_hits, vector, doc_type, doc_tensor, query_tensor)
      result.add(raw_recall)
    end
  end

  def fetch_file_to_localhost(remote_file, local_file)
    proxy_node = @vespa.nodeproxies.values.first
    proxy_file = nn_download_file(remote_file, proxy_node)
    proxy_node.copy_remote_file_to_local_file(proxy_file, local_file)
  end

  def calc_recall_in_searcher(target_hits, explore_hits, query_vector, doc_type, doc_tensor, query_tensor)
    query = get_query_for_recall_searcher(target_hits, explore_hits, query_vector, doc_type, doc_tensor, query_tensor)
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

  def get_query_for_recall_searcher(target_hits, explore_hits, query_vector, doc_type, doc_tensor, query_tensor)
    "query=sddocname:#{doc_type}&summary=minimal&ranking.features.query(#{query_tensor})=#{query_vector}" +
    "&nnr.enable=true&nnr.docTensor=#{doc_tensor}&nnr.targetHits=#{target_hits}&nnr.exploreHits=#{explore_hits}" +
    "&nnr.queryTensor=#{query_tensor}"
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
