# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'feed_and_query_test_base'

class FlatToHierarchicTransitionTest < FeedAndQueryTestBase

  def create_flat_group_app(node_count: 2, redundancy: 1, searchable: 1)
    SearchApp.new.cluster(
      SearchCluster.new("mycluster").sd(selfdir + "test.sd").
      redundancy(redundancy).ready_copies(searchable).num_parts(node_count)).
      storage(StorageCluster.new("mycluster", node_count))
  end

  def create_hierarchic_2groups_app
    SearchApp.new.cluster(
      SearchCluster.new("mycluster").sd(selfdir + "test.sd").
      redundancy(2).ready_copies(2).num_parts(2).
      group(NodeGroup.new(0, "mytopgroup").
            distribution("1|*").
            group(NodeGroup.new(0, "mygroup0").
                  node(NodeSpec.new("node1", 0))).
            group(NodeGroup.new(1, "mygroup1").
                  node(NodeSpec.new("node1", 1))))).
      storage(StorageCluster.new("mycluster", 2))
  end

  def assert_satisfied_within_timeout(timeout: 60*2)
    start = Time.now
    while !yield
      if Time.now - start > timeout
        flunk "Block condition not satisfied after #{timeout} seconds"
      end
      sleep 1
    end
  end

  def last_metric_value(metrics, name)
    metrics.get(name)["last"].to_i
  end

  def each_search_node
    vespa.search["mycluster"].searchnode.each_value { |node|
      yield node
    }
  end

  def all_search_nodes_converged(document_count: 0)
    each_search_node { |node|
      stats = node.get_state_v1_custom_component("/documentdb/test")
      doc_stats = stats["documents"]

      total = doc_stats["total"]
      ready = doc_stats["ready"]
      active = doc_stats["active"]

      puts "node #{node.index}: total(#{total}), ready(#{ready}), active(#{active})"
      return false if (total != document_count ||
                       ready  != document_count ||
                       active != document_count)
    }
    true
  end

  def test_transition_implicitly_indexes_and_activates_docs_per_group
    set_owner("vekterli")
    set_description("Converting from a flat to a hierarchic cluster model " +
                    "should replicate, index and activate documents on a " +
                    "per-group basis. See VESPA-1015 for context.")
    deploy_app(create_flat_group_app())
    start

    n_docs = 20
    generate_and_feed_docs(n_docs)

    deploy_app(create_hierarchic_2groups_app())

    assert_satisfied_within_timeout {
      all_search_nodes_converged(document_count: n_docs)
    }
  end
end
