# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_only_search_test'

class FastAccessAttributesTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  def get_app(sd_file)
    SearchApp.new.sd(selfdir + sd_file).
      num_parts(2).redundancy(2).ready_copies(1)
  end

  def get_search_node(node_idx)
    vespa.search["search"].searchnode[node_idx]
  end

  def assert_attribute_exists(attr_name, attr_stats)
    assert(attr_stats[attr_name] != nil, "Expected attribute '#{attr_name}' to exist")
  end

  def assert_attribute_not_exists(attr_name, attr_stats)
    assert(attr_stats[attr_name] == nil, "Expected attribute '#{attr_name}' not to exist")
  end

  def assert_attributes_exist_on_node(node_idx, not_ready_exists)
    puts "assert_attributes_exist_on_node(#{node_idx}, #{not_ready_exists})"

    search_node = get_search_node(node_idx)
    ready_attrs = search_node.get_state_v1_custom_component("/documentdb/test/subdb/ready/attribute")
    not_ready_attrs = search_node.get_state_v1_custom_component("/documentdb/test/subdb/notready/attribute")

    assert_attribute_exists("a1", ready_attrs)
    assert_attribute_exists("a2", ready_attrs)

    assert_attribute_exists("a1", not_ready_attrs) if not_ready_exists
    assert_attribute_not_exists("a1", not_ready_attrs) if !not_ready_exists
    assert_attribute_not_exists("a2", not_ready_attrs)
  end

  def redeploy(sd_file)
    deploy_output = super(get_app(sd_file))
    node_0 = get_search_node(0)
    node_1 = get_search_node(1)
    do_wait_for_application(deploy_output)
    wait_for_and_handle_config(node_0, "0")
    wait_for_and_handle_config(node_1, "1")
  end

  def do_wait_for_application(deploy_output)
    wait_for_application(vespa.container.values.first, deploy_output)
  end

  def verify_need_restart(node)
    status = node.get_proton_status
    assert(status.match(/"WARNING","state=ONLINE configstate=NEED_RESTART","DocumentDB delaying attribute aspects changes in config/))
  end

  def wait_for_and_handle_config(node, node_idx)
    verify_need_restart(node)
    # set node in maintenance to avoid re-distribution on the other node
    vespa.storage["search"].get_master_fleet_controller().set_node_state("storage", node_idx.to_i, "s:m")
    vespa.storage["search"].storage[node_idx].wait_for_current_node_state('m')
    node.stop
    node.start
    vespa.storage["search"].get_master_fleet_controller().set_node_state("storage", node_idx.to_i, "s:u")
    vespa.storage["search"].storage[node_idx].wait_for_current_node_state('u')
    wait_for_hitcount("sddocname:test", 16)
  end

  def assert_attribute_hitcount
    wait_for_hitcount("a1:10", 8)
    wait_for_hitcount("a1:20", 8)
  end

  def assert_attributes_exist(not_ready_exists)
    assert_attributes_exist_on_node(0, not_ready_exists)
    assert_attributes_exist_on_node(1, not_ready_exists)
  end

  def verify_documents_moved_from_notready_to_ready
    # Verify that all documents are moved from not-ready to ready sub db on node 0
    stop_node_and_wait("search", "1")
    wait_for_hitcount("sddocname:test", 16)
    assert_attribute_hitcount
  end

  def enable_debug
    vespa.adminserver.logctl("distributor:distributor.stripe_bucket_db_updater", "debug=on,spam=on")
    vespa.adminserver.logctl("distributor2:distributor.stripe_bucket_db_updater", "debug=on,spam=on")
    vespa.adminserver.logctl("distributor:distributor.operation.idealstate.setactive", "debug=on")
    vespa.adminserver.logctl("distributor2:distributor.operation.idealstate.setactive", "debug=on")
    vespa.adminserver.logctl("searchnode:persistence.filestor.modifiedbucketchecker", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:persistence.bucketownershipnotifier", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:persistence.persistencehandler", "debug=on")
  end

  def test_add_fast_access_attribute
    set_description("Verify that a fast access attribute can be added and populated in the not-ready sub database")
    deploy_app(get_app("sd1/test.sd"))
    start
    enable_debug
    feed_and_wait_for_docs("test", 16, :file => selfdir + "docs.xml")
    assert_attributes_exist(false)

    redeploy("sd2/test.sd")
    # node 0
    assert_log_matches(/.populate\.attribute\.complete.*test\.2\.notready\.attribute\.a1.*documents\.populated":9/)
    # node 1
    assert_log_matches(/.populate\.attribute\.complete.*test\.2\.notready\.attribute\.a1.*documents\.populated":7/)

    feed(:file => selfdir + "updates.xml")
    assert_attribute_hitcount
    assert_attributes_exist(true)

    verify_documents_moved_from_notready_to_ready
  end

  def test_remove_fast_access_attribute
    set_description("Verify that a fast access attribute can be removed and document store populated in the not-ready sub database")
    deploy_app(get_app("sd2/test.sd"))
    start
    enable_debug
    feed_and_wait_for_docs("test", 16, :file => selfdir + "docs.xml")
    feed(:file => selfdir + "updates.xml")
    assert_attribute_hitcount
    assert_attributes_exist(true)

    redeploy("sd1/test.sd")
    # node 0
    assert_log_matches(/.populate\.documentfield\.complete.*test\.2\.notready\.documentfield\.a1.*documents\.populated":9/)
    # node 1
    assert_log_matches(/.populate\.documentfield\.complete.*test\.2\.notready\.documentfield\.a1.*documents\.populated":7/)
    assert_attribute_hitcount
    assert_attributes_exist(false)

    verify_documents_moved_from_notready_to_ready
  end

  def teardown
    stop
  end

end
