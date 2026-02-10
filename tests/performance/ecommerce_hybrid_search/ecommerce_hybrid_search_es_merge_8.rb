# Copyright Vespa.ai. All rights reserved.

require_relative 'ecommerce_hybrid_search_es_base'
require 'json'

class EcommerceHybridSearchESForceMerge8Test < EcommerceHybridSearchESTestBase

  def setup
    super
    set_owner("hmusum")
  end

  def test_hybrid_search
    set_description("Test performance of hybrid search on ES using an E-commerce dataset (feeding, force merge to 8 segments, queries)")
    return if should_skip?
    @node = vespa.nodeproxies.values.first
    prepare_es_app

    es_feed(feed_file_name, get_num_docs, @feed_threads, "feed", true)
    benchmark_force_merge(get_num_docs, 8)
    benchmark_queries("after_merge", false, [1, 16, 64])
    benchmark_queries("after_merge", true, [1, 16, 64])
  end

  def teardown
    stop_es unless should_skip?
    super
  end

end
