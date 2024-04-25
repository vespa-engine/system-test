# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'

class EcommerceHybridSearchTest < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def test_hybrid_search
    set_description("Test performance of hybrid search using an E-commerce dataset (feeding, queries, re-feeding with queries)")

    deploy(selfdir + "app")
    @container = vespa.container.values.first
    start
  end

  def teardown
    super
  end

end
