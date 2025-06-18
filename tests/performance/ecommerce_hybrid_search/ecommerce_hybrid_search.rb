# Copyright Vespa.ai. All rights reserved.

require_relative 'ecommerce_hybrid_search_base'
require 'json'

class EcommerceHybridSearchTest < EcommerceHybridSearchTestBase

  def test_hybrid_search
    set_description("Test performance of hybrid search using an E-commerce dataset (feeding, queries, re-feeding with queries)")
    deploy(selfdir + "app")
    @container = vespa.container.values.first
    @search_node = vespa.search["search"].first
    @minimal = false
    start
    dump_thread_stats

    benchmark_feed(feed_file_name, "feed")

    @search_node.trigger_flush
    benchmark_queries("after_flush", false, [1, 2, 4, 8, 16, 32, 64])
    benchmark_queries("after_flush", true, [1, 2, 4, 8, 16, 32, 64])

    benchmark_feed(feed_file_name, "refeed")
    benchmark_feed("vespa_update-1M.json.zst", "update")

    feed_thread = Thread.new { benchmark_feed(feed_file_name, "refeed_with_queries") }
    sleep 2
    benchmark_queries("during_refeed", true, [1, 16, 64], {:runtime => 9})
    feed_thread.join

    write_performance_results_to_json_file
  end

  def feed_file_name
    @minimal ? "vespa_feed-10k.json.zst" : "vespa_feed-1M.json.zst"
  end

  def benchmark_feed(feed_file, label)
    node_file = download_file(feed_file, vespa.adminserver)
    system_sampler = Perf::System::new(vespa.search["search"].first)
    system_sampler.start
    fillers = [parameter_filler("label", label), system_metric_filler(system_sampler)]
    profiler_start
    run_feeder(node_file, fillers, {:client => :vespa_feed_client,
                                    :compression => "none",
                                    :localfile => true,
                                    :silent => true,
                                    :disable_tls => false})
    profiler_report(label)
  end

  def benchmark_queries(query_phase, run_filter_queries, clients, params = {})
    if run_filter_queries
      benchmark_query("vespa_queries-weak_and-filter-10k.json", query_phase, "weak_and_filter", clients, params)
      benchmark_query("vespa_queries-semantic-filter-10k.json", query_phase, "semantic_filter", clients, params)
      benchmark_query("vespa_queries-hybrid-filter-10k.json", query_phase, "hybrid_filter", clients, params)
    else
      benchmark_query("vespa_queries-weak_and-10k.json", query_phase, "weak_and", clients, params)
      benchmark_query("vespa_queries-semantic-10k.json", query_phase, "semantic", clients, params)
      benchmark_query("vespa_queries-hybrid-10k.json", query_phase, "hybrid", clients, params)
    end
  end

  def benchmark_query(query_file, query_phase, query_type, clients, params)
    clients.each do |c|
      run_fbench_helper(query_file, query_phase, query_type, c, @container, params)
    end
  end

  def dump_thread_stats
    stats = @search_node.get_state_v1_custom_component("/threadpools")
    puts "threadpools stats:"
    puts JSON.pretty_generate(stats)
  end

end
