# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'vds_test'
require 'json'

class ClusterControllerTest < VdsTest

  def setup
    @docnr = 0
    @valgrind=false
    set_owner("vekterli")
    app = default_app.provider("PROTON")
    app.admin(Admin.new.clustercontroller("node1").
                        clustercontroller("node1").
                        clustercontroller("node1"))
    app.redundancy(2).num_nodes(2)
    deploy_app(app)
    start
  end

  def can_share_configservers?(method_name=nil)
    false
  end

    # The bucket count test currently have to wait for 5 minute shapshot to
    # be taken
  def timeout_seconds
    return 600
  end

  def feed_docs(doccount = 10)
    puts "\nFEEDING DOCS\n"
    doccount.times { |i|
      nr = @docnr
      @docnr += 1
      doc = Document.new("music", "id:storage_test:music::" + nr.to_s).
        add_field("title", "title")
      vespa.document_api_v1.put(doc)
    }
  end

  def distributor(index)
    vespa.storage["storage"].distributor[index.to_s]
  end

  def wait_until_distributor_owns_n_docs(index:, expected:)
    while distributor(index).get_numdoc_stored != expected
      puts "Distributor #{index} document count: #{distributor(index).get_numdoc_stored}"
      sleep 1
    end
  end

  def test_controller_takeover
    # Feed 10 docs. Verify that both distributors get expected document counts.
    feed_docs
    wait_until_distributor_owns_n_docs(index: 0, expected: 4)
    wait_until_distributor_owns_n_docs(index: 1, expected: 6)
    # Take down master cluster controller
    vespa.clustercontrollers["0"].stop()
    # Take down one distributor
    distributor(0).stop()
    distributor(1).wait_until_synced()
    # Feed 10 more docs. Should still work as long as new cluster
    # controller has taken over
    feed_docs
    wait_until_distributor_owns_n_docs(index: 1, expected: 20)
  end

  def wait_until_cluster_state_matches(regex)
    timeout_after_sec = 120
    ok = vespa.storage['storage'].wait_for_state_condition(timeout_after_sec) { |state|
      state.statestr =~ regex
    }
    assert(ok, "Failed to reach state matching '#{regex}' within #{timeout_after_sec} seconds")
  end

  def test_content_node_maintenance_mode_with_safe_condition_implicitly_affects_distributor
    set_description('Test that setting a content node to Maintenance state with "safe" ' +
                    'condition implicitly sets distributor on same node into Down state, ' +
                    'and that this is reversed when setting content node back Up.')
    feed_docs # Have some docs to report merge stats on
    vespa.storage['storage'].get_master_cluster_controller.set_node_state('storage', 'storage', 0, 's:m', 'safe')
    wait_until_cluster_state_matches(/distributor:2 .0.s:d storage:2 .0.s:m/)
    vespa.storage['storage'].get_master_cluster_controller.set_node_state('storage', 'storage', 0, 's:u', 'safe')
    wait_until_cluster_state_matches(/distributor:2 storage:2$/)
  end

  def test_status_page
    page = vespa.clustercontrollers["0"].get_status_page("/clustercontroller-status/v1/")
    puts page
    assert_match(/.*href="\.\/storage".*/, page)
    page = vespa.clustercontrollers["0"].get_status_page("/clustercontroller-status/v1/storage")
    puts page
    assert_match(/.*storage Cluster Controller 0 Status Page.*/, page) # Headline
    assert_match(/.*cluster controller master is node 0.*/, page) # Master info
    assert_match(/.*Number of storage nodes.*/, page) # Config
    assert_match(/.*a href="storage\/node=distributor\.1".*/, page) # Link
    page = vespa.clustercontrollers["0"].get_status_page("/clustercontroller-status/v1/storage/node=distributor.1")
    puts page
    assert_match(/.*Cluster Controller Status Page - Node status for distributor\.1.*/, page)
    assert_match(/.*href="\.\.">Back to cluster.*/, page)
  end
  
  # Useful test wrapper to test manually faster, avoiding setup and teardown
  # waits between all tests.
  def no_test_all
    feed_docs(2)
    test_state_rest_api_get()
    test_state_rest_api_recursive_get()
    test_state_rest_api_bucket_count()
    test_state_rest_api_redirect_to_master()
  end

  def test_state_rest_api_get
        # The various calls are unit tested, so important here is just to test
        # the integration. Doing a few differnt calls here just to be sure
        # though, but not testing all the content.
    page = vespa.clustercontrollers["0"].get_status_page("/cluster/v2/")
    puts page
    json = JSON.parse(page)
    assert_equal("/cluster/v2/storage", json["cluster"]["storage"]["link"])

    page = vespa.clustercontrollers["0"].get_status_page("/cluster/v2/storage")
    puts page
    json = JSON.parse(page)
    assert_equal("up", json["state"]["generated"]["state"])
    assert_equal("/cluster/v2/storage/storage",
                 json["service"]["storage"]["link"])

    page = vespa.clustercontrollers["0"].get_status_page(
            "/cluster/v2/storage/storage/0")
    puts page
    json = JSON.parse(page)
    assert_equal("", json["attributes"]["hierarchical-group"])
  end

  def test_state_rest_api_recursive_get
    add_expected_logged(/No known master cluster controller currently exists./)
    page = vespa.clustercontrollers["0"].get_status_page(
            "/cluster/v2/?recursive=true")
    puts page
    json = JSON.parse(page)
    assert_equal("up", json["cluster"]["storage"]["service"]["storage"]["node"]["0"]["state"]["user"]["state"])
  end

  def test_state_rest_api_redirect_to_master
    # Non-master cluster controller can answer cluster list
    page = vespa.clustercontrollers["1"].get_status_page("/cluster/v2/")
    puts page
    json = JSON.parse(page)
    assert_equal("/cluster/v2/storage", json["cluster"]["storage"]["link"])

    # But nothing else
    response, data = vespa.clustercontrollers["1"].http_request(
            "/cluster/v2/storage?recursive=true")
    assert_equal('307', response.code, response.message)
    assert_equal('Temporary Redirect', response.message)
    assert_match(/^http[s]?:\/\/[^\/]+\/cluster\/v2\/storage\?recursive=true$/,
                 response["Location"])

    # Check that the redirection work
    puts "Fetching status from URL we got redirected to: '" +
         "#{response["Location"]}'."
    masterurl = URI(response["Location"]);
    response = https_client.get(masterurl.host, masterurl.port, masterurl.path, query: masterurl.query)
    puts response.body()
    assert_equal(200, response.code.to_i, response.message)
    json = JSON.parse(response.body())
    assert_equal("up", json["service"]["storage"]["node"]["0"]["state"]["user"]["state"], page)

    # Take down one controller.. New master should respond
    vespa.clustercontrollers["0"].stop()
    puts "Waiting for cluster controller 1 to report as master. (Have to wait" +
         " beyond the master cooldown period, which currently is 60 seconds " +
         "in default config)"
    1000000.times { |i|
        response, data = vespa.clustercontrollers["1"].http_request(
                "/cluster/v2/storage")
        if (response.code == "200")
            puts data
            json = JSON.parse(data)
            assert_equal("up", json["state"]["generated"]["state"])
            assert_equal("/cluster/v2/storage/storage",
                         json["service"]["storage"]["link"])
            break
        elsif (i > 1000)
            flunk("Did not manage to get ok response from node that should be new master within timeout")
        else
            print "."
            STDOUT.flush
        end
        sleep(1)
    }
  end

  def get_cluster_v2_storage_bucket_count(node_idx, deadline)
    while Time.now < deadline
      response, data = vespa.clustercontrollers["0"].http_request("/cluster/v2/storage/storage/#{node_idx}")
      if response.code.to_i == 200
        json = JSON.parse(data)
        if json == nil || json["metrics"] == nil || json["metrics"]["bucket-count"] == nil
          next
        else
          return json["metrics"]["bucket-count"].to_i
        end
      else
        puts "HTTP #{response.code.to_i}, retrying"
      end
      sleep 1
    end
    flunk "Did not manage to get bucket count within deadline"
  end

  def make_cc_deadline
    Time.now + 60*5
  end

  def test_state_rest_api_bucket_count
    feed_docs(2)
    puts "Waiting for bucket count metric to be visible in State Rest API"
    buckets = 0
    deadline = make_cc_deadline
    while true
      buckets = get_cluster_v2_storage_bucket_count(0, deadline)
      puts buckets
      # At this point, bucket count will be either 0, 1 or 2, but shall eventually be stable at 2
      # It's possible that the internal DB bucket count snapshot happens _after_ doc 1 has been fed
      # but _before_ doc 2 has been fed, hence the possibility of observing 1 document.
      break if buckets == 2
      sleep 1
    end

    # Restarting a content node should never surface an outdated bucket count through the API
    vespa.stop_content_node('storage', '0')
    vespa.start_content_node('storage', '0')

    buckets = get_cluster_v2_storage_bucket_count(0, deadline) # Waits for visibility
    assert_equal(2, buckets)
  end

  def test_content_node_safe_down_is_well_defined_after_node_restart
    set_description('Tests that content nodes do not transiently report erroneous bucket metrics to ' +
                    'the cluster controller after process restart. Erroneous metrics may cause the cluster ' +
                    'controller to believe a permanent Down transition is safe even when it is not.')
    feed_docs # creates 10 buckets

    cluster = vespa.storage['storage']
    # Tag node 0 as retired. This is a precondition for triggering safe permanently Down checks
    cluster.get_master_cluster_controller.set_node_state('storage', 'storage', 0, 's:r')
    vespa.stop_content_node('storage', '0')
    vespa.start_content_node('storage', '0', 60, false) # Don't wait until state Up
    cluster.wait_for_current_node_state('storage', 0, 'r', 60)

    cluster_state = cluster.get_master_cluster_controller.get_cluster_state('storage')
    cluster.wait_for_cluster_state_propagate(cluster_state, 120, 'uir')

    # The node must report a consistent number of buckets to the cluster controller upon first
    # contact. This must in turn disallow safe permanently Down-edges, as these are only allowed
    # when there are no buckets left on the node. Note that safe Maintenance mode _would_ have
    # been allowed, as we expect those nodes to come back online again.
    # We loop this until we get the expected error message, as SetNodeState calls may observe
    # false negatives caused by transient cluster convergence issues (such as not yet having
    # received host info matching the most recently published cluster state).
    deadline = make_cc_deadline
    while true
      deny_reason = nil
      begin
        cluster.get_master_cluster_controller.set_node_state('storage', 'storage', 0, 's:d', 'safe')
      rescue => e
        deny_reason = e.message
        puts "Failed to set node state (this is expected): #{e}"
      end
      if deny_reason.nil?
        flunk 'Was allowed to set node down in safe mode even with buckets present'
      end
      # This is a bit too leaky for comfort, but we don't have any other mechanisms of
      # knowing _why_ a particular SetNodeState request failed.
      if deny_reason =~ /The storage node stores 10 documents and 0 tombstones across 10 buckets/
        puts 'Got expected failure message, all is well'
        break
      end
      if Time.now > deadline
        flunk 'Timed out waiting for CC to give expected response'
      end
      sleep 1
    end
  end

  def test_system_framework_able_to_get_state_with_index_0_down
    test_state_rest_api_redirect_to_master()
    vespa.storage["storage"].wait_until_ready
  end

  def verify_node_count(count, timeout = 60)
    current = nil
    timeout.times { |i|
        page = vespa.clustercontrollers["0"].get_status_page("/cluster/v2/storage/storage")
        puts page
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

