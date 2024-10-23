# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/stat'

class MmapVsDirectIoTest < PerformanceTest

  def timeout_seconds
    1200
  end

  def setup
    super
    set_owner('vekterli')
  end

  def teardown
    super
  end

  def test_wikipedia_corpus_search_performance
    set_description('Test search performance on English Wikipedia corpus and query set '+
                    'when file reading is done via either mmap or Direct IO')
    deploy_app(make_app(search_direct_io: false))
    @search_node = vespa.search['search'].first
    @container = vespa.container.values.first
    start

    query_file_name = 'squad2-questions.fbench.141k.txt'
    report_io_stat_deltas do
      feed_file('enwiki-20240801-pages.6819k.jsonl.zst')
    end

    @search_node.trigger_flush # Shovel everything into a disk index
    @search_node.execute("du -hS #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.search/")

    # One-shot warmup round with many clients. This helps measure contention for paging in data.
    # Note that we don't tag as "warmup=true", as we want profiling enabled here as well.
    puts "Warming up mmap'ed region with 64 clients"
    report_io_stat_deltas do
      benchmark_queries(query_file_name, 'mmap_warmup', 64, false)
    end
    puts "Searching with mmap-backed search stores"

    [8, 16, 32, 64].each do |clients|
      report_io_stat_deltas do
        benchmark_queries(query_file_name, 'mmap', clients, false)
      end
    end

    vespa.stop_content_node('search', 0)

    puts "Redeploying with Direct IO for searches"
    deploy_app(make_app(search_direct_io: true))
    # Model has changed under our feet, must refresh remote objects.
    @search_node = vespa.search['search'].first
    @container = vespa.container.values.first

    vespa.start_content_node('search', 0)
    sleep 2 # Allow for container health pings to catch up

    puts "Searching with Direct IO-backed search stores"
    [8, 16, 32, 64].each do |clients|
      report_io_stat_deltas do
        benchmark_queries(query_file_name, 'directio', clients, false)
      end
    end

    stop
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

  def make_app(search_direct_io:)
    SearchApp.new.sd(selfdir + 'wikimedia.sd').
      container(Container.new('default').
        jvmoptions("-Xms16g -Xmx16g").
        search(Searching.new).
        docproc(DocumentProcessing.new).
        documentapi(ContainerDocumentApi.new)).
      indexing_cluster('default').
      indexing_chain('indexing').
      config(ConfigOverride.new('vespa.config.search.core.proton').
        add('search', ConfigValue.new('io', search_direct_io ? 'DIRECTIO' : 'MMAP')))
  end

  def report_io_stat_deltas
    stat_before = @search_node.performance_snapshot
    yield
    stat_after = @search_node.performance_snapshot
    puts Perf::Stat::snapshot_period(stat_before, stat_after).printable_result
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
                 :use_post => false,
                 :runtime => runtime,
                 :result_file => result_file},
                fillers)
    profiler_report(label) if not warmup
    @container.execute("head -12 #{result_file}")
  end

end

