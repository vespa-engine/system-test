# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'
require 'pp'

class ProtonStateServer < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_proton_state
    generation = get_generation(deploy_app(SearchApp.new.sd(selfdir + "test.sd"))).to_i
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.json")
    node = @vespa.search["search"].first
    metrics = node.get_state_v1_metrics
    # node should be reporting itself as up
    assert_equal("up", metrics["status"]["code"])
    config = node.get_state_v1_config
    # pp config
    assert_equal(generation, config["config"]["proton"]["generation"])
    assert_equal(generation, config["config"]["proton.documentdb.test"]["generation"])
  end

  def test_monitoring_snapshot_period
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").monitoring("test", "60"))
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.json")
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


end
