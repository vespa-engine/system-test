# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_search_test'
require 'pp'

class FdispatchStateServer < IndexedSearchTest

  def nightly?
    true
  end

  def setup
    set_owner("havardpe")
  end

  def test_fdispatch_state
    generation = get_generation(deploy_app(SearchApp.new.sd(selfdir + "test.sd"))).to_i
    start
    feed_and_wait_for_docs("test", 5, :file => selfdir + "docs.xml")
    node = @vespa.search["search"].first_tld
    metrics = node.get_state_v1_metrics
    pp metrics
    assert_equal("up", metrics["status"]["code"])
    assert_nil(metrics["metrics"])
    config = node.get_state_v1_config
    pp config
    assert_equal(generation, config["config"]["fdispatch"]["generation"])
    assert_equal(generation, config["config"]["fdispatch.nodemanager"]["generation"])
  end

  def teardown
    stop
  end

end
