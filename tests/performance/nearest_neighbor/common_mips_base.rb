# Copyright Vespa.ai. All rights reserved.

require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/nearest_neighbor/common_ann_base'

class CommonMipsBase < CommonAnnBaseTest

  FBENCH_TIME = 30

  def initialize(*args)
    super(*args)
    @data_path = "mips-data/"
  end

  def explore_hits_levels
    [0, 90, 190, 490]
  end

  def run_mips_test(sd_file, feed_file, doc_type, query_tensor)
    deploy_app(create_app(sd_file))
    start
    @container = vespa.container.values.first

    feed_and_benchmark(feed_file, "docs", doc_type, "embedding")
    query_and_benchmark
    prepare_queries_for_recall
    explore_hits_levels.each do |explore_hits|
      params = {:doc_type => doc_type, :doc_tensor => "embedding", :query_tensor => query_tensor}
      calc_recall_for_queries(10, explore_hits, params)
    end
  end

  def run_quantized_mips_test(sd_file, feed_file, doc_type, query_tensor, qbits)
    deploy_app(create_app(sd_file))
    start
    @container = vespa.container.values.first

    feed_and_benchmark(feed_file, 'docs', doc_type, 'embedding', false)
    query_and_benchmark

    prepare_queries_for_recall
    params = {:doc_type => doc_type,
              :doc_tensor => 'embedding',
              :exact_match_tensor => 'embedding_f32',
              :exact_match_rank_profile => 'full_precision_exact_match',
              :approx_match_rank_profile => 'default',
              :query_tensor => query_tensor,
              :quantization_bits => qbits}
    # First, do an exact match search between the full precision and quantized tensors
    # in order to determine the inherent loss from quantization itself, and to derive
    # an upper bound for the HNSW recall for the same quantization level.
    puts '------'
    puts "Calculating max theoretical recall by comparing full precision vs. quantized exact search hits"
    puts '------'
    calc_recall_for_queries(10, 0, params.merge({:use_exact_for_approx_match_phase => true}))
    # Followed by HNSW approximate matches with varying explore-hits levels
    explore_hits_levels.each do |explore_hits|
      puts '------'
      puts "Computing HNSW recall for varying explore-hits=#{explore_hits}"
      puts '------'
      calc_recall_for_queries(10, explore_hits, params)
    end

  end

  def create_app(sd_file)
    add_bundle(selfdir + "NearestNeighborRecallSearcher.java")
    searching = Searching.new
    searching.chain(Chain.new("default", "vespa").add(Searcher.new("ai.vespa.test.NearestNeighborRecallSearcher")))
    SearchApp.new.sd(sd_file).
      threads_per_search(1).
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(searching).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer")
  end

  def query_and_benchmark
    algorithm = "hnsw"
    target_hits = 100
    explore_hits = 0
    label = "#{algorithm}-th#{target_hits}-eh#{explore_hits}"
    query_file = fetch_query_file_to_container
    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(TYPE, "query"),
               parameter_filler(LABEL, label),
               parameter_filler(ALGORITHM, algorithm),
               parameter_filler(TARGET_HITS, target_hits),
               parameter_filler(EXPLORE_HITS, explore_hits)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => 1,
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -10 #{result_file}")
  end

  def fetch_query_file_to_container
    proxy_file = nn_download_file(@queries, @container)
    puts "Got on container: #{proxy_file}"
    return proxy_file
  end

end
