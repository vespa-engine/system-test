# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class UseLocalNodeTest < SearchTest

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    set_owner("balder")
    deploy_app(SearchApp.new.cluster(
        SearchCluster.new.sd(SEARCH_DATA + "music.sd").redundancy(2).ready_copies(2).
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
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.xml")
    vespa.search["search"].searchnode[0].stop
    vespa.search["search"].searchnode[1].stop
    wait_for_hitcount("music", 0, 10)
    vespa.qrserver.each_value do |container|
      host= container.name
      r=container.search("/search/?query=sddocname:music&nocache&hits=0")
    end
    matches = wait_for_atleast_log_matches(/Cluster dispatcher.search: group 0 has reduced coverage: Active documents: 0\/0, working nodes: 0\/1 required 1, unresponsive nodes:/, 2, 120, {:multinode => true})
    assert(matches <= 6, "The test should see 2 to 6 reports for group 0 coverage, saw #{matches}")
  end

  def teardown
    stop
  end

end
