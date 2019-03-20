# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'multi_provider_storage_test'

class FleetControllerAddNode < MultiProviderStorageTest

  def setup
    # We do support adding distr/storage on new nodes, but not on nodes already running storaged due to allocation of ports. May be solved by supporting port configuration instead of dynamically allocation of ports
    set_owner("vekterli")

    deploy_app(default_app.num_nodes(2))
    start
  end

  def tst_addnode
    vespa.storage["storage"].wait_for_node_count("distributor", 2, "u")
    vespa.storage["storage"].wait_for_node_count("storage", 2, "u")

    puts "Stage 1 complete"

    deploy_app(default_app.num_nodes(3).redundancy(3))

    vespa.storage["storage"].wait_for_node_count("distributor", 3, "u")
    vespa.storage["storage"].wait_for_node_count("storage", 3, "u")

    puts "Stage 2 complete"

    deploy_app(default_app.num_nodes(2).redundancy(2))

    vespa.storage["storage"].wait_for_node_count("distributor", 2, "u")
    vespa.storage["storage"].wait_for_node_count("storage", 2, "u")
    vespa.storage["storage"].wait_for_node_count("distributor", 1, "d")
    vespa.storage["storage"].wait_for_node_count("storage", 1, "d")
  end

  def teardown
    stop
  end
end

