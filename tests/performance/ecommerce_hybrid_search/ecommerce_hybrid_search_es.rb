# Copyright Vespa.ai. All rights reserved.

require_relative 'ecommerce_hybrid_search_es_base'
require 'json'

class EcommerceHybridSearchESTest < EcommerceHybridSearchESTestBase

  def setup
    super
    set_owner("geirst")
  end

  def test_hybrid_search
    set_description("Test performance of hybrid search on ES using an E-commerce dataset (feeding, queries, re-feeding with queries)")
    @node = vespa.nodeproxies.values.first
    prepare_es_app

    benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "feed")
    dump_jvm_stats

    flush_index
    benchmark_queries("after_flush", false, [1, 2, 4, 8, 16, 32, 64])
    benchmark_queries("after_flush", true, [1, 2, 4, 8, 16, 32, 64])

    benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "refeed")
    benchmark_update("es_update-1M.json.zst", get_num_docs, @feed_threads)

    feed_thread = Thread.new { benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "refeed_with_queries") }
    sleep 2
    benchmark_queries("during_refeed", true, [1, 16, 64], {:runtime => 9})
    feed_thread.join

    write_performance_results_to_json_file
  end

  def teardown
    stop_es
    super
  end

end
