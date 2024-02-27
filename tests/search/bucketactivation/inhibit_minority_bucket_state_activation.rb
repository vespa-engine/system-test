# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'
require 'doc_generator'

class InhibitMinorityBucketStateActivationTest < IndexedOnlySearchTest

  def setup
    set_owner('vekterli')
    set_description('Test that bucket activation behavior can be configured to inhibit ' +
                    'the activation of bucket replicas whose metadata state differs from  ' +
                    'that of the majority.')
  end

  def make_app(disable_merges:)
    SearchApp.new.
      cluster(SearchCluster.new('storage').
              sd(SEARCH_DATA+'test.sd').
              redundancy(3).ready_copies(3).
              group(NodeGroup.new(0, 'root').
                    distribution('1|1|*').
                    group(NodeGroup.new(0, 'g0').node(NodeSpec.new('node1', 0))).
                    group(NodeGroup.new(1, 'g1').node(NodeSpec.new('node1', 1))).
                    group(NodeGroup.new(2, 'g2').node(NodeSpec.new('node1', 2))))).
      storage(StorageCluster.new('storage', 3)).
      enable_document_api.
      config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
             add('merge_operations_disabled', disable_merges).
             add('max_activation_inhibited_out_of_sync_groups', 1))
  end

  def teardown
    stop
  end

  def content_cluster
    vespa.storage['storage']
  end

  def test_can_configure_activation_inhibition_of_minority_state_bucket_replicas
    deploy_app(make_app(disable_merges: true))
    start

    feed_n_docs_with_field_value(20, 'foo')
    wait_for_hitcount('query=f1:foo&nocache', 20)

    set_node_state('storage', 1, 'd')
    feed_n_docs_with_field_value(20, 'bar')
    wait_for_hitcount('query=f1:bar&nocache', 20)

    # All docs are now out of sync with the majority (nodes 0, 2) on node 1.
    # When it's taken back up, buckets should _not_ be automatically activated on it.
    set_node_state('storage', 1, 'u')
    vespa.adminserver.execute('vespa-stat --document id:test:test::doc-0')
    # Serve all docs from groups 0, 2
    assert_group_hitcount(0, 'bar', 20)
    assert_group_hitcount(2, 'bar', 20)
    # But nothing from group 1
    assert_group_hitcount(1, 'foo', 0)
    assert_group_hitcount(1, 'bar', 0)

    # Once merges complete and replicas are in sync, all replicas should be active.
    gen = get_generation(deploy_app(make_app(disable_merges: false)))
    # Ensure that config is visible on nodes (and triggering ideal state ops) before running wait_until_ready
    vespa.storage['storage'].wait_until_content_nodes_have_config_generation(gen.to_i)
    wait_until_ready
    vespa.adminserver.execute('vespa-stat --document id:test:test::doc-0')
    assert_group_hitcount(0, 'bar', 20)
    assert_group_hitcount(1, 'bar', 20)
    assert_group_hitcount(2, 'bar', 20)
  end

  def assert_group_hitcount(group, field_value, expected)
    assert_hitcount("query=f1:#{field_value}&nocache&model.searchPath=0/#{group}", expected)
  end

  def set_node_state(type, idx, state)
    content_cluster.get_master_fleet_controller().set_node_state(type, idx, "s:#{state}")
  end

  def feed_n_docs_with_field_value(n, field_value)
    n.times{|i|
      doc = Document.new('test', "id:test:test::doc-#{i}")
      doc.add_field('f1', field_value)
      puts doc.documentid
      vespa.document_api_v1.put(doc, :brief => true)
    }
  end

end

