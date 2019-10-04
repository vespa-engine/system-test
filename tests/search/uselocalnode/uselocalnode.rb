# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class UseLocalNodeTest < SearchTest

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("balder")
    deploy_app(SearchApp.new.cluster(
        SearchCluster.new.sd(SEARCH_DATA + "music.sd").use_local_node(true).redundancy(2).ready_copies(2).
               group(NodeGroup.new(0, "topgroup").
                     distribution("1|*").
                     group(NodeGroup.new(0, "group0").node(NodeSpec.new("node1", 0))).
                     group(NodeGroup.new(1, "group1").node(NodeSpec.new("node2", 1))))).
        num_hosts(2).
        container(Container.new.node({:hostalias => "node1"}).
                                node({:hostalias => "node2"}).
                                search(Searching.new)))
    start
  end

  def test_uselocalnode_javadispatch
    run_test("&dispatch.internal=true")
  end

  def run_test(query_append)
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.xml")
    vespa.search["search"].searchnode[0].stop
    vespa.search["search"].searchnode[1].stop
    wait_for_hitcount("music", 0, 10)
    vespa.qrserver.each_value do |container|
      host= container.name
      # Excplicitly go through dispatch so that it generates the log messages we test for
      r=container.search("/search/?query=sddocname:music&nocache&hits=0&dispatch.direct=false#{query_append}")
    end
    matches = wait_for_atleast_log_matches(/.*Coverage of group 0 is only 0\/1 [(]requires 1[)]/, 2, 120, {:multinode => true})
    assert(matches <= 100, "The test should see 2 to 4 reports for group 0 coverage, saw #{matches}")
    assert_log_not_matches(/.*Coverage of group 1 is only 0\/1 [(]requires 1[)]/, {:multinode => true})
  end

  def teardown
    stop
  end

end
