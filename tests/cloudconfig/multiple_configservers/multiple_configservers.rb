# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'cloudconfig_test'
require 'search_test'
require 'indexed_search_test'
require 'json'
require 'environment'

class MultipleConfigservers < CloudConfigTest

  def initialize(*args)
    super(*args)
    @num_hosts = 3
  end

  def timeout_seconds
    1800
  end

  def nightly?
    false
  end

  def setup
    @valgrind = false
    set_description("Tests that multiple configservers work. When one server goes down, " +
                    "the other should continue to serve config.")
    set_owner("musum")
    @session_id = 1
    add_bundle_dir(File.expand_path(selfdir), "com.yahoo.vespatest.ExtraHitSearcher")
    vespa.nodeproxies.values.each do |node|
      override_environment_setting(node, "cloudconfig_server__zookeeper_barrier_timeout", "70")
    end
    output = deploy_multiple_app(selfdir + "banana.sd")
    @session_id = get_generation(output).to_i
    @node1 = vespa.configservers["0"]
    @node2 = vespa.configservers["1"]
    @node3 = vespa.configservers["2"]
    assert_activation_status
    verify_configs(@node1, [@node1.hostname, @node2.hostname, @node3.hostname])
    start
    feed_and_wait_for_docs("banana", 3, :file => selfdir+"bananafeed.xml")
    debug("started")
  end

  def deploy_multiple_app(sd)
    deploy_app(SearchApp.new.sd(sd).
      search_chain(SearchChain.new.add(Searcher.new(
      "com.yahoo.vespatest.ExtraHitSearcher"))).
      num_hosts(3).
      configserver("node1").
      configserver("node2").
      configserver("node3"), 
      { :timeout => 120 })
  end

  def test_session_states
    deploy_multiple_app(selfdir + "extended_sd/banana.sd")
    @session_id = @session_id + 1

    assert_activation_status

    # Activation status of previous session should be inactive
    assert_prepared_response(@node1, "message", "Session not prepared: #{@session_id - 1}", @session_id - 1)
    assert_prepared_response(@node2, "message", "Session not prepared: #{@session_id - 1}", @session_id - 1)
    assert_prepared_response(@node3, "message", "Session not prepared: #{@session_id - 1}", @session_id - 1)

    #assert_prepared_response_key(@node1, @session_id - 1, "activate")
    #assert_prepared_response_key(@node2, @session_id - 1, "activate")
    #assert_prepared_response_key(@node3, @session_id - 1, "activate")

    wait_for_config_generation_on_all_configservers(@session_id)
    wait_for_reconfig(600, true)
    feed_and_wait_for_docs("banana", 5, :file => selfdir + "bananafeed-extended.xml")
  end

  def test_deploy_robustness
    set_expected_logged(Regexp.union(/Connection timed out for connection string/ , /Sequential path not found/, /Fleetcontroller \d: Got no data from node entry at/, /has content that does not match its hash, deleting everything in/))
    wait_for_config_generation_on_all_configservers(@session_id)
    # session_id = 2
    @session_id = @session_id + 1
    # session_id = 3
    create_session_from_url = "http://#{@node1.hostname}:19071/application/v2/tenant/default/application/default/environment/prod/region/default/instance/default"
    puts "Create session url:#{create_session_from_url}"
    result = create_session_v2_with_uri(@node1.hostname, "default", create_session_from_url, @session_id)
    @node2.stop_configserver({:keep_everything => true})
    sleep 3
    prepare_session_message_matches(@node1.hostname, result, 200, /Session #{@session_id} for tenant 'default' prepared/)
    @node2.start_configserver
    @node2.ping_configserver
    sleep 3
    result = prepare_session_with_timeout(@node1.hostname, result, @session_id, 60)
    sleep 3
    @node3.stop_configserver({:keep_everything => true})
    activate_session_message_matches(@node1.hostname, result, 200, /Session #{@session_id} for tenant 'default' activated/)
    @node3.start_configserver
    @node3.ping_configserver
    sleep 3
    wait_for_config_generation_on_all_configservers(@session_id)
  end

  def test_failovers
    set_expected_logged(Regexp.union(/Connection timed out for connection string/ , 
                                     /Sequential path not found/, 
                                     /Fleetcontroller \d: Got no data from node entry at/,
                                     /Fleetcontroller \d: Failure code \d when listening to node at \/vespa\/fleetcontroller/,
                                     /Fleetcontroller \d: Strangely, we already had data from node \d when trying to remove it/,
                                     /Fatal error killed fleet controller/,
                                     /Unable to load class '.*' because the bundle wiring for zkfacade is no longer valid/))
    # stop the first configserver and restart vespa, the other configservers should serve config
    vespa.configservers["0"].stop_configserver({:keep_everything => true})
    debug("4")
    vespa.stop_base
    debug("5")
    vespa.start_base
    debug("6")
    wait_for_sddocname_banana_hitcount(3, 600)
    debug("7")

    vespa.configservers["0"].start_configserver
    wait_for_config_generation_on_all_configservers(@session_id)
    debug("")
    deploy_multiple_app(selfdir+"extended_sd/banana.sd")
    @session_id = @session_id + 1
    debug("9")
    wait_for_config_generation_on_all_configservers(@session_id)
    feed_and_wait_for_docs("banana", 5, :file => selfdir+"bananafeed-extended.xml")
    debug("10")

    # stop the second configserver and restart vespa, the other configservers should serve config
    vespa.configservers["1"].stop_configserver({:keep_everything => true})
    debug("11")
    vespa.stop_base
    debug("12")
    vespa.start_base
    debug("13")
    wait_for_sddocname_banana_hitcount(5)
    debug("14")

    # stop remaining configservers too, config should now be served from configproxy cache
    vespa.configservers["0"].stop_configserver({:keep_everything => true})
    debug("15")
    vespa.configservers["2"].stop_configserver({:keep_everything => true})
    debug("16")
    vespa.container.values.first.stop
    debug("17")
    vespa.container.values.first.start
    debug("18")
    wait_for_sddocname_banana_hitcount(5)
    debug("19")

    vespa.stop_base
    debug("20")
    vespa.configservers["0"].start_configserver
    vespa.configservers["1"].start_configserver
    vespa.configservers["2"].start_configserver
  end

  # Test that deleting an application works when done on another server than the
  # one the application was deployed to
  def test_delete_application
    apps = list_applications_v2(@node1.hostname, "default")
    assert_equal(1, apps.length)

    sesssion_path = "#{Environment.instance.vespa_home}/var/db/vespa/config_server/serverdb/tenants/default/sessions/#{@session_id}"
    # Verify that app was deployed on node1
    @node1.execute("ls #{sesssion_path}")

    # Delete app on another node than deployment was done on
    delete_application_v2(@node2.hostname, "default", "default")
    # App should be deleted at once, both on node1 and node 2
    apps = list_applications_v2(@node2.hostname, "default")
    assert_equal(0, apps.length)
    apps = list_applications_v2(@node1.hostname, "default")
    assert_equal(0, apps.length)
    # Verify that app does not exist in file system on the node it was deleted on (other nodes will be cleaned up asynchronously)
    @node1.execute("sync") # Sync to disk to  make sure we read latest changes
    # Returns array with exit code and output from 'ls'. Check for exit code 2, which means that the path does not exist
    assert_equal("2",  @node2.execute("ls #{sesssion_path}", {:exitcode => true, :exceptiononfailure => false})[0])
  end

  def scratch_zk(node)
    node.execute("rm -rf #{Environment.instance.vespa_home}/var/zookeeper/*")
  end

  def assert_prepared_response(node, json_field, expected, session_id=@session_id)
    assert_get_response(node, session_id, "prepared", json_field, expected)
  end

  def assert_prepared_response_key(node, session_id, json_field)
    response = @node2.https_client.get('localhost', 19071, "/application/v2/tenant/default/session/#{session_id}/prepared")
    json = JSON.parse(response.body)
    assert(json.has_key?(json_field))
  end

  def assert_get_response(node, session_id, session_url, json_field, expected)
    response = node.https_client.get('localhost', 19071, "/application/v2/tenant/default/session/#{session_id}/#{session_url}")
    json = JSON.parse(response.body)
    assert_equal(expected, json[json_field])
  end

  def assert_activation_status
    assert_prepared_response(@node1, "message", "Session is active: #{@session_id}")
    assert_prepared_response(@node2, "message", "Session is active: #{@session_id}")
    assert_prepared_response(@node3, "message", "Session is active: #{@session_id}")
  end 

  def get_config(node)
    node.execute("vespa-get-config -n cloud.config.log.logd -i \"\" -p 19070 -w 10")
  end

  def execute_on_all_configservers(command)
    vespa.configservers.each_value do |node|
      node.execute(command)
    end
  end

  def wait_for_config_generation_on_all_configservers(generation)
    vespa.configservers.each_value do |node|
      wait_for_config_generation(generation, "document.config.documentmanager", "client", node)
    end
  end

  def wait_for_sddocname_banana_hitcount(count, timeout=180)
    wait_for_hitcount("query=sddocname:banana", count, timeout)
  end

  def teardown
    stop
    vespa.nodeproxies.values.each do |node|
      override_environment_setting(node, "cloudconfig_server__zookeeper_barrier_timeout", nil)
    end
  end

  def debug(msg)
    vespa.nodeproxies.values.each do |n|
      n.execute("echo #{msg} >> /tmp/node_server.log")
    end
  end

end
