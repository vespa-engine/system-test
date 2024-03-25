# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class MultipleClusterControllers < IndexedStreamingSearchTest

  def initialize(*args)
    super(*args)
    @num_hosts = 3
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def setup
    set_description("Tests that multiple cluster controllers are implicitly setup when having a content cluster (one on each config server)")
    set_owner("vekterli")
    deploy_multiple_app(selfdir + "banana.sd")
    start
    feed_and_wait_for_docs("banana", 2, :file => selfdir+"bananafeed.xml")
  end

  def deploy_multiple_app(sd)
    deploy_app(SearchApp.new.sd(sd).
      enable_document_api.
      num_hosts(3).
      configserver("node1").
      configserver("node2").
      configserver("node3"))
  end

  # Verify that then multiple config servers are used, multiple cluster controllers
  # are also set up.
  def test_multiple_clustercontrollers
    vespa.configservers["0"].execute("vespa-model-inspect service container-clustercontroller ; echo ensure exit code 0")
    cluster_controller_count = vespa.configservers["0"].execute("vespa-model-inspect service container-clustercontroller 2>/dev/null | grep container-clustercontroller | wc -l").to_i
    assert_equal(3, cluster_controller_count)
  end

  def teardown
    stop
  end
end
