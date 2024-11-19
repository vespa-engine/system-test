# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class FeedingWhileDistributorsDieTest < VdsTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app.num_nodes(4).redundancy(1))
    start
  end

  def stop_distributor(idx)
    vespa.storage["storage"].distributor[idx.to_s].stop
    vespa.storage["storage"].distributor[idx.to_s].wait_for_current_node_state('d')
  end

  def start_distributor(idx)
    vespa.storage["storage"].distributor[idx.to_s].start
    vespa.storage["storage"].distributor[idx.to_s].wait_for_current_node_state('u')
  end

  def test_feedingwhiledistributorsdie
    set_expected_logged(Regexp.union(/Added node only event: Event: distributor.0: Failed get node state request: Connection error:/))
    feederoutput = ""
    feederthread = Thread.new do
      feederoutput = vespa.storage["storage"].storage["0"].feedfile(selfdir + "data.json", :maxretries => 5, :client => :vespa_feed_client)
    end

    stop_distributor 0
    start_distributor 0

    stop_distributor 0

    sleep 1

    stop_distributor 1

    sleep 1

    start_distributor 0
    start_distributor 1

    feederthread.join

    assert(feederoutput.index("\"feeder.ok.count\" : 1000"))
    assert(feederoutput.index("\"feeder.error.count\" : 0"))
  end

  def teardown
    vespa.storage["storage"].storage["0"].kill_process("vespa-feed-client")
    stop
  end

end
