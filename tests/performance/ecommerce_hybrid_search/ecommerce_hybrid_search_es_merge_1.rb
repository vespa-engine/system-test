# Copyright Vespa.ai. All rights reserved.

require_relative 'ecommerce_hybrid_search_es_base'
require 'json'

class EcommerceHybridSearchESForceMerge1Test < EcommerceHybridSearchESTestBase

  def setup
    super
    set_owner("geirst")
  end

  def test_hybrid_search
    set_description("Test performance of hybrid search on ES using an E-commerce dataset (feeding, force merge to 1 segment, queries)")
    @node = vespa.nodeproxies.values.first
    prepare_es_app

    benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "feed")
    benchmark_force_merge(get_num_docs, 1)
    dump_jvm_stats
    benchmark_queries("after_merge", false, [1, 2, 4, 8, 16, 32, 64])
    benchmark_queries("after_merge", true, [1, 2, 4, 8, 16, 32, 64])

    write_performance_results_to_json_file
  end

  def teardown
    stop_es
    super
  end

end
