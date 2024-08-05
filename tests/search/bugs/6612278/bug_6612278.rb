# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'
require 'search/utils/elastic_doc_generator'

class Bug6612278Test < IndexedOnlySearchTest
  def setup
    set_owner('vekterli')
    set_description('Test that merging with limits does not cause wrong ' +
                    'ordering of source-only copies')
    set_expected_logged(/Search node .* went bad/)
  end

  def teardown
    stop
  end

  def generate_app(nodes, redundancy)
    SearchApp.new.sd(selfdir+'test.sd').
      cluster_name("mycluster").num_parts(nodes).
      redundancy(redundancy).ready_copies(redundancy).
      config(ConfigOverride.new("vespa.config.content.core.stor-distributormanager").
             add("maximum_nodes_per_merge", 2)).
      storage(StorageCluster.new("mycluster", nodes).distribution_bits(8))
  end

  def set_node_down(type, idx)
    vespa.adminserver.execute("vespa-set-node-state -t #{type} -i #{idx} down " +
                              "'set down by test'")
  end

  def set_node_up(type, idx)
    vespa.adminserver.execute("vespa-set-node-state -t #{type} -i #{idx} up")
  end

  def test_merge_with_node_limits
    deploy_app(generate_app(4, 4))
    start
    feed(:file => "#{selfdir}/feed1.json")

    # We now have 4 copies. Take down 2 and feed over the remaining 2 buckets
    # so that the buckets on the downed nodes are guaranteed to be out of sync
    # once they come back up. Then decrease redundancy so 2 of the buckets must
    # become source only copies.
    set_node_down('storage', 0)
    set_node_down('storage', 1)
    wait_until_ready

    feed(:file => "#{selfdir}/feed2.json")
    config_generation = get_generation(deploy_app(generate_app(4, 2))).to_i
    wait_for_reconfig(config_generation) # To ensure new distribution config has kicked.

    set_node_up('storage', 1)
    set_node_up('storage', 0)
    wait_until_ready
  end
end

