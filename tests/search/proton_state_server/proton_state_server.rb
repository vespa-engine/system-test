# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_search_test'
require 'pp'

class ProtonStateServer < IndexedSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_proton_state
    generation = get_generation(deploy_app(SearchApp.new.sd(selfdir + "test.sd"))).to_i
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.xml")
    node = @vespa.search["search"].first
    metrics = node.get_state_v1_metrics
    # node should be reporting itself as up
    assert_equal("up", metrics["status"]["code"])
    config = node.get_state_v1_config
    # pp config
    assert_equal(generation, config["config"]["proton"]["generation"])
    assert_equal(generation, config["config"]["proton.documentdb.test"]["generation"])
  end

  def test_yamas_snapshot_period
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").monitoring("test", "60"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.xml")
    node = @vespa.search["search"].first
    period = 0
    sleep(60) # wait for metrics snapshot
    tries = 120
    begin
      sleep(1)
      metrics = node.get_state_v1_metrics
      period = metrics["metrics"]["snapshot"]["to"].to_f - metrics["metrics"]["snapshot"]["from"].to_f
    end while (period == 0 && tries > 0)
    assert(period < 200)
  end

  def teardown
    stop
  end

end
