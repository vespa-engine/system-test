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
    benchmark_queries("after_feed", false, [1, 2, 4, 8, 16, 32, 64])
    benchmark_queries("after_feed", true, [1])
    feed_thread = Thread.new { benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "refeed") }
    sleep 5
    benchmark_queries("during_refeed", false, [1])
    feed_thread.join
    benchmark_update("es_update-1M.json.zst", get_num_docs, @feed_threads)
  end

  def teardown
    stop_es
    super
  end

end
