# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesNeedRefeedReconfigTest < IndexedSearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  def test_need_refeed_reconfig
    set_description("Test that a document database needs refeed when adding index aspect to existing field")
    @test_dir = selfdir + "need_refeed/"
    exp_logged = 
      Regexp.union(/proton\.server\.configvalidator.*Cannot add index field `f2', it has existed as a field before/,
                   /proton\.server\.documentdb.*Cannot apply new config snapshot, new schema is in conflict with old schema or history/)
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    enable_proton_debug_log
    vespa.adminserver.logctl("searchnode:proton.server.proton_config_fetcher", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.bootstrapconfigmanager", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config.proxy.ConfigProxyRpcServer", "debug=on")
    vespa.adminserver.logctl("searchnode:common.configmanager", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.documentdb", "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.proton", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:common.configagent", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:engine.transportserver", "debug=on,spam=on")
    enable_proton_debug_log
    proton = vespa.search["search"].first
    proton.logctl2("proton.docsummary.documentstoreadapter", "all=on")
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.xml")

    puts "need refeed reconfig of f2"
    redeploy_output = redeploy("test.1.sd")
    assert_match(/Consider re-indexing document type 'test' in cluster 'search'.*\n.*Field 'f2' changed: add index aspect/, redeploy_output)

    tenant = use_shared_configservers ? @tenant_name : "default"
    application = use_shared_configservers ? @application_name : "default"
    application_url = "https://#{vespa.configservers["0"].name}:#{vespa.configservers["0"].ports[1]}/application/v2/tenant/#{tenant}/application/#{application}/environment/prod/region/default/instance/default/"

    # Wait for convergence of all services in the application — specifically document processors 
    start_time = Time.now
    until get_json(http_request(URI(application_url + "serviceconverge"), {}))["converged"] or Time.now - start_time > 60 # seconds
      sleep 1
    end
    assert(Time.now - start_time < 60, "Services should converge on new generation within the minute")
    assert(3 == get_json(http_request(URI(application_url + "serviceconverge"), {}))["wantedGeneration"], "Should converge on generation 3")
    puts "Services converged on new config generation after #{Time.now - start_time} seconds"

    # Feed should be accepted
    feed_output = feed(:file => @test_dir + "feed.1.xml", :timeout => 20, :exceptiononfailure => false)
    # Search & docsum should still work
    assert_result("sddocname:test&nocache", @test_dir + "result.1.xml")
    assert_hitcount("f1:b&nocache", 2)
    assert_hitcount("f3:%3E29&nocache", 2)

    # Read baseline reindexing status — very first reindexing is a no-op in the reindexer controller
    response = http_request(URI(application_url + "reindexing"), {})
    assert(response.code.to_i == 200, "Request should be successful")
    previous_reindexing_timestamp = get_json(response)["status"]["readyMillis"]

    # Allow the reindexing maintainer some time to run, and mark the first no-op reindexing as done
    sleep 60

    # Trigger reindexing through reindexing API in /application/v2, and verify it was triggered
    response = http_request_post(URI(application_url + "reindex"), {})
    assert(response.code.to_i == 200, "Request should be successful")

    response = http_request(URI(application_url + "reindexing"), {})
    assert(response.code.to_i == 200, "Request should be successful")
    current_reindexing_timestamp = get_json(response)["status"]["readyMillis"]
    assert(previous_reindexing_timestamp < current_reindexing_timestamp,
           "Previous reindexing timestamp (#{previous_reindexing_timestamp}) should be after current (#{current_reindexing_timestamp})")

    # Redeploy again to trigger reindexing, then wait for up to 5 minutes for document 1 to be reindexed
    redeploy("test.1.sd")
    start_time = Time.now
    until search("sddocname:test&nocache").hit.select { |h| h.field["a1"] == h.field["f3"] }.length == 2 or Time.now - start_time > 300 # seconds
      sleep 1
    end
    assert_result("sddocname:test&nocache", @test_dir + "result.2.xml")
    puts "Reindexing complete after #{Time.now - start_time} seconds"
  end

  def test_that_changing_the_tensor_type_of_a_tensor_attribute_needs_refeed
    set_description("Tests that changing the tensor type of a tensor attribute needs refeed")
    @test_dir = selfdir + "change_tensor_type/"

    # Deploy
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)

    # Feed should be accepted
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>0.0},
                         {'address'=>{'x'=>'1'}, 'value'=>47.0}], do_search, "f1")

    # Redeploy with changed tensor type
    redeploy_output = redeploy("test.1.sd")
    assert_match("Field 'f1' changed: tensor type: 'tensor(x[2])' -> 'tensor(x[3])'", redeploy_output)
    # Existing document no longer has content as type is changed
    assert(do_search.hit[0].field["f1"] == nil)

    # Feed should be accepted
    feed_output = feed(:file => @test_dir + "feed.1.json", :timeout => 20, :exceptiononfailure => false)
    result = do_search
    assert_hitcount(result, 2);
    assert(result.hit[0].field["f1"] == nil)
    assert_tensor_field([{'address'=>{'x'=>'0'}, 'value'=>0.0},
                         {'address'=>{'x'=>'1'}, 'value'=>0.0},
                         {'address'=>{'x'=>'2'}, 'value'=>47.0}], result, "f1", 1)
  end

  def do_search
    result = search("query=sddocname:test&format=json")
    result.sort_results_by("id")
    result
  end

  def teardown
    stop
  end

end
