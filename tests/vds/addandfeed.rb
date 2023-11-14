# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class AddNodeAndFeed < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.num_nodes(2).redundancy(2))
    start
  end

  def test_addnodeandfeed
    vespa.stop_content_node("storage", "1")
    vespa.storage["storage"].distributor["1"].stop

    vespa.storage["storage"].storage["1"].wait_for_current_node_state('d')
    vespa.storage["storage"].distributor["1"].wait_for_current_node_state('d')

    feedfile(selfdir+"data/base64.xml")	

    vespa.start_content_node("storage", "1")
    vespa.storage["storage"].distributor["1"].start

    feedfile(selfdir+"data/base64.xml")
    vespa.storage["storage"].distributor["1"].wait_for_current_node_state('u')
  end

  def teardown
    stop
  end
end

