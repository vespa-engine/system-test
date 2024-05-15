# coding: utf-8
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesNeedRefeedReconfigTest < IndexedOnlySearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  # Application and tenant names changes based on the context this is run in.
  def application_url
    tenant = use_shared_configservers ? @tenant_name : "default"
    application = use_shared_configservers ? @application_name : "default"
    "https://#{vespa.nodeproxies.first[1].addr_configserver[0]}:#{19071}/application/v2/tenant/#{tenant}/application/#{application}/environment/prod/region/default/instance/default/"
  end

  def test_need_refeed_reconfig
    set_description("Test that a document database needs refeed when adding index aspect to existing field, and that this can be solved by reindexing")
    @test_dir = selfdir + "need_refeed/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    enable_proton_debug_log
    #vespa.adminserver.logctl("searchnode:proton.server.proton_config_fetcher", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.bootstrapconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config.proxy.ConfigProxyRpcServer", "debug=on")
    #vespa.adminserver.logctl("searchnode:common.configmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdb", "debug=on")
    #vespa.adminserver.logctl("searchnode:proton.server.proton", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:common.configagent", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:engine.transportserver", "debug=on,spam=on")
    proton = vespa.search["search"].first
    proton.logctl2("proton.docsummary.documentstoreadapter", "all=on")
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")

    puts "need refeed reconfig of f2"
    redeploy_output = redeploy("test.1.sd", "indexing-change")
    gen = get_generation(redeploy_output).to_i
    assert_match(/Consider re-indexing document type 'test' in cluster 'search'.*\n.*Field 'f2' changed: add index aspect/, redeploy_output)

    reindexing_ready_millis = get_reindexing_initial_ready_millis
    wait_for_convergence(gen)

    # Feed should be accepted
    feed_output = feed(:file => @test_dir + "feed.1.json", :timeout => 20, :exceptiononfailure => false)
    # Search & docsum should still work
    assert_result("sddocname:test", @test_dir + "result.1.json")
    assert_hitcount("f1:b", 2)
    assert_hitcount("f3:%3E29", 2)

    wait_for_reindexing_to_be_ready(reindexing_ready_millis)
    # Redeploy again to trigger reindexing, then wait for up to 2 minutes for document 1 to be reindexed
    redeploy("test.1.sd")
    start_time = Time.now
    until search("sddocname:test").hit.select { |h| h.field["a1"] == h.field["f3"] }.length == 2 or Time.now - start_time > 120 # seconds
      sleep 1
    end
    assert_result("sddocname:test", @test_dir + "result.2.json")
    puts "Reindexing complete after #{Time.now - start_time} seconds"
  end

  def test_need_refeed_after_indexing_mode_change
    set_description("Test that a document database needs refeed when changing indexing mode of a document, and that this can be solved by reindexing")
    @test_dir = selfdir + "need_refeed/"

    # This whole framework was never meant to allow changing indexing mode >_<
    @params[:search_type] = "STREAMING"
    app = SearchApp.new.sd(use_sdfile("test.1.sd")).
              config(ConfigOverride.new('vespa.config.content.fleetcontroller').
                  add('ideal_distribution_bits', 8)).
              config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
                  add('minsplitcount', 8)).
              validation_override("indexing-mode-change")
    deploy_output = deploy_app(app)
    start
    postdeploy_wait(deploy_output)
    enable_proton_debug_log
    #vespa.adminserver.logctl("searchnode:proton.server.proton_config_fetcher", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.bootstrapconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config.proxy.ConfigProxyRpcServer", "debug=on")
    #vespa.adminserver.logctl("searchnode:common.configmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdb", "debug=on")
    #vespa.adminserver.logctl("searchnode:proton.server.proton", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:common.configagent", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:engine.transportserver", "debug=on,spam=on")
    proton = vespa.search["search"].first
    proton.logctl2("proton.docsummary.documentstoreadapter", "all=on")
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")

    @params[:search_type] = "INDEXED"
    vespa.stop_base # Indexing mode change leads to changed config id for search nodes, a restart is required
    redeploy_output = deploy_app(app)
    gen = get_generation(redeploy_output).to_i
    assert_match(/Document type 'test' in cluster 'search' changed indexing mode from 'streaming' to 'indexed'/, redeploy_output)

    start
    reindexing_ready_millis = get_reindexing_initial_ready_millis
    wait_for_convergence(gen)

    # Feed should be accepted
    feed_output = feed(:file => @test_dir + "feed.1.json", :timeout => 20, :exceptiononfailure => false)
    # Search & docsum should still work also for genrated fields
    assert_result("sddocname:test", @test_dir + "result.2.json")
    assert_hitcount("f1:b", 1)          # No index for old document
    assert_hitcount("f3:%3E29", 2)      # But attributes work

    wait_for_reindexing_to_be_ready(reindexing_ready_millis)
    # Redeploy again to trigger reindexing, then wait for up to 2 minutes for document 1 to be reindexed
    deploy_app(app)
    start_time = Time.now
    wait_for_hitcount("f1:b", 2, 120) # Wait for refeed to populate index with annotations.
    assert_result("sddocname:test", @test_dir + "result.2.json")
    puts "Reindexing complete after #{Time.now - start_time} seconds"
  end

  # Wait for convergence of all services in the application — specifically document processors
  def wait_for_convergence(generation)
    start_time = Time.now
    until get_json(http_request(URI(application_url + "serviceconverge"), {}))["converged"] or Time.now - start_time > 120 # seconds
      sleep 1
    end
    assert(Time.now - start_time < 120, "Services should converge on new generation within the minute")
    assert(generation == get_json(http_request(URI(application_url + "serviceconverge"), {}))["wantedGeneration"],
           "Should converge on generation #{generation}")
    puts "Services converged on new config generation after #{Time.now - start_time} seconds"
  end

  # Wait for new document types to be discovered by the reindexer, and then trigger reindexing of the whole corpus
  def get_reindexing_initial_ready_millis
    # Read baseline reindexing status — very first reindexing is a no-op in the reindexer controller
    response = http_request(URI(application_url + "reindexing"), {})
    assert(response.code.to_i == 200, "Request should be successful")
    get_json(response)["clusters"]["search"]["ready"]["test"]["readyMillis"]
  end

  # Verify reindexing is automatically triggered by the new schema activation, after convergence
  def wait_for_reindexing_to_be_ready(previous_reindexing_timestamp)
    start_time = Time.now
    until Time.now - start_time > 210 # seconds
      response = http_request(URI(application_url + "reindexing"), {})
      assert(response.code.to_i == 200, "Request should be successful")
      current_reindexing_timestamp = get_json(response)["clusters"]["search"]["ready"]["test"]["readyMillis"]
      if current_reindexing_timestamp.nil?
        next
      elsif previous_reindexing_timestamp.nil? || previous_reindexing_timestamp < current_reindexing_timestamp
        break
      end
      sleep 1
    end
    assert(Time.now - start_time < 210, "Reindexing should be ready within a few minutes of service convergence, but status was: #{get_json(response)}")
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
    redeploy_output = redeploy("test.1.sd", "field-type-change")
    assert_match("Field 'f1' changed: data type: 'tensor(x[2])' -> 'tensor(x[3])'", redeploy_output)
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
    result = search("query=sddocname:test&format=json&format.tensors=long")
    result.sort_results_by("id")
    result
  end

  def teardown
    stop
  end

end
