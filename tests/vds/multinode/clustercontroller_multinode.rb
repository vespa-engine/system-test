# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'
require 'json'

class ClusterControllerMultiNodeTest < VdsTest

  def initialize(*args)
    super(*args)
    @num_hosts = 4
  end

  def can_share_configservers?(method_name=nil)
    return false
  end
  
  def setup
    @docnr = 0
    @valgrind = false
    set_owner("vekterli")

    @sdf = VDS + "schemas/music.sd"
    @two = selfdir + "app2"
    @four = selfdir + "app4"
    puts "[progress] Using #{@sdf}"
    deploy(@four, @sdf)
    start
    puts "[progress] STARTED with #{@four}"
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def test_live_reconfig
    verify_node_count(4)
    decrease_cluster_to_two_nodes()
    verify_node_count(2, 1)
    increase_cluster_to_four_nodes()
    verify_node_count(4)
    puts "[progress] all OK."
  end

  def decrease_cluster_to_two_nodes
    @vespa.stop_base
    puts "[progress] DEPLOY #{@two}"
    deploy(@two, @sdf)
    puts "[progress] #{@two} DEPLOYED"
    start
  end

  def increase_cluster_to_four_nodes
    puts "[progress] DEPLOY #{@four}"
    deploy(@four, @sdf)
    puts "[progress] #{@four} DEPLOYED"
  end

  def verify_node_count(count, timeout = 60)
    current = nil
    timeout.times { |i|
        page = vespa.clustercontrollers["0"].get_status_page("/cluster/v2/storage/storage")
        puts "[current status page] #{page}"
        json = JSON.parse(page)
        current = json["node"].length
        if (current == count)
            return
        end
        sleep(1)
    }
    flunk("Failed to get to node count #{count} within #{timeout} seconds. Current count #{current}")
  end

  def teardown
    stop
  end
end

