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
    # feed should be accepted
    feed_output = feed(:file => @test_dir + "feed.1.xml", :timeout => 20, :exceptiononfailure => false)
    # search & docsum should still work
    assert_result("sddocname:test&nocache", @test_dir + "result.1.xml")
    assert_hitcount("f1:b&nocache", 2)
    assert_hitcount("f3:%3E29&nocache", 2)
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
