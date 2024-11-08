# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/stat'

class MmapVsDirectIoTest < PerformanceTest

  def timeout_seconds
    1800
  end

  def setup
    super
    set_owner('vekterli')
  end

  def teardown
    super
  end

  def testing_locally?
    false
  end

  def test_profile
    if testing_locally?
      { :doc_count      => 50_000,
        :query_runtime  => 20,
        :cache_sizes_mb => [0, 16, 128, 512] }
    else
      { :doc_count      => -1,
        :query_runtime  => 30,
        :cache_sizes_mb => [0, 24, 256, 10 * 1024] }
    end
  end

  def test_wikipedia_corpus_search_performance
    set_description('Test search performance on English Wikipedia corpus and query set '+
                    'when file reading is done via either mmap or Direct IO')
    deploy_app(make_app(search_io_mode: 'MMAP'))
    @search_node = vespa.search['search'].first
    @container = vespa.container.values.first
    start

    @profile = test_profile

    @query_file_name = 'squad2-questions.fbench.141k.txt'
    @no_stop_words_query_file_name = 'squad2-questions.max-df-20.fbench.141k.txt'

    report_io_stat_deltas do
      feed_file('enwiki-20240801-pages.1M.jsonl.zst', @profile[:doc_count])
    end

    @search_node.trigger_flush # Shovel everything into a disk index
    @search_node.execute("du -hS #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/")

    # MMap provides the baseline (expected best case) query performance, assuming all index data fits in memory.
    deploy_and_run_queries(search_io_mode: 'MMAP')

    ['DIRECTIO', 'NORMAL'].each do |io_mode|
      @profile[:cache_sizes_mb].each do |cache_size_mb|
        deploy_and_run_queries(search_io_mode: io_mode, cache_size_mb: cache_size_mb)
      end
    end

    stop
  end

  # Feeding must already have been done (using MMAP search_io_mode)
  def deploy_and_run_queries(search_io_mode:, cache_size_mb: 0)
    if search_io_mode != 'MMAP'
      vespa.stop_content_node('search', 0)
      puts "----------"
      puts "Redeploying app with `search.io` mode '#{search_io_mode}', cache size #{cache_size_mb} MiB"
      puts "----------"
      deploy_app(make_app(search_io_mode: search_io_mode, cache_size_mb: cache_size_mb))
      @search_node = vespa.search['search'].first
      @container = vespa.container.values.first
      vespa.start_content_node('search', 0)
      sleep 2 # Allow for container health pings to catch up
    end

    pretty_mode = search_io_mode.downcase
    cache_desc = cache_size_mb > 0 ? "#{cache_size_mb}mb_cache" : "nocache"
    run_type = "#{pretty_mode}_#{cache_desc}"
    clients = 64

    unless search_io_mode == 'DIRECTIO' and cache_size_mb == 0
      puts "Warming up cache"
      report_io_stat_deltas do
        benchmark_queries(@query_file_name, "#{run_type}_warmup", clients, true, @profile[:query_runtime])
      end
    end

    puts "Searching with '#{pretty_mode}' search store backing using #{clients} clients"
    report_io_stat_deltas do
      benchmark_queries(@query_file_name, run_type, clients, false, @profile[:query_runtime])
    end
    report_io_stat_deltas do
      benchmark_queries(@no_stop_words_query_file_name, "#{run_type}_no_stop_words", clients, false, @profile[:query_runtime])
    end
  end

  def feed_file(feed_file, n_docs = -1)
    node_file = download_file(feed_file, vespa.adminserver)
    # JSONL source, so `head` works nicely to efficiently limit to N docs from the feed
    limit_cmd = n_docs <= 0 ? '' : " | head -#{n_docs}"

    run_stream_feeder("zstdcat #{node_file}#{limit_cmd}", [],
                      {:client => :vespa_feed_client,
                       :compression => 'none',
                       :localfile => true,
                       :silent => true,
                       :disable_tls => false})
  end

  def download_file(file_name, vespa_node)
    download_file_from_s3(file_name, vespa_node, 'wikipedia')
  end

  def make_app(search_io_mode:, cache_size_mb: 0)
    app = SearchApp.new.sd(selfdir + 'wikimedia.sd').
      container(Container.new('default').
        jvmoptions("-Xms16g -Xmx16g").
        search(Searching.new).
        docproc(DocumentProcessing.new).
        documentapi(ContainerDocumentApi.new)).
      indexing_cluster('default').
      indexing_chain('indexing').
      search_io(search_io_mode)

    if search_io_mode != 'MMAP'
      app.config(ConfigOverride.new('vespa.config.search.core.proton').
        add('index', ConfigValue.new('postinglist',
          ConfigValue.new('cache', ConfigValue.new('maxbytes', cache_size_mb * 1024 * 1024)))))
    end
    app
  end

  def report_io_stat_deltas
    stat_before = @search_node.performance_snapshot
    yield
    stat_after = @search_node.performance_snapshot
    puts Perf::Stat::snapshot_period(stat_before, stat_after).printable_result({:filter => [:sys, :disk]})
  end

  # TODO dedupe
  def benchmark_queries(query_file, type, clients, warmup = false, runtime = 20)
    node_file = download_file(query_file, @container)
    label = "#{type}_#{clients}"
    result_file = dirs.tmpdir + "result_#{label}.txt" # TODO don't include?
    fillers = [parameter_filler("label", label),
               parameter_filler("type", type),
               parameter_filler("clients", clients)]
    profiler_start if not warmup
    run_fbench2(@container,
                node_file,
                {:clients => clients,
                 :append_str => '&presentation.summary=minimal&hits=10',
                 :use_post => false,
                 :runtime => runtime,
                 :result_file => result_file},
                fillers)
    profiler_report(label) if not warmup
    @container.execute("head -12 #{result_file}")
  end

end

