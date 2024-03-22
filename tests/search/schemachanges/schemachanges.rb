require 'indexed_only_search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChanges < IndexedOnlySearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  def timeout_seconds
    return 900
  end

  def get_metrics_match_msg(matches)
    msg = "these metrics matched:\n"
    matches.each do |m|
      msg += "#{m["name"]}\n"
    end
    return msg
  end

  def get_all_attributes
    attributes = vespa.search["search"].first.get_state_v1_custom_component("/documentdb/test/subdb/ready/attribute")
    puts "get_all_attributes: #{attributes}"
    return attributes
  end

  def get_all_documentdbs
    documentdbs = vespa.search["search"].first.get_state_v1_custom_component["documentdb"]
    puts "get_all_documentdbs: #{documentdbs}"
    return documentdbs
  end

  def assert_attributes_exist(exp_attributes)
    act_attributes = get_all_attributes
    assert_equal(exp_attributes.size, act_attributes.size)
    assert_equal(exp_attributes.sort, act_attributes.keys.sort)
  end

  def assert_documentdbs_exist(exp_documentdbs)
    act_documentdbs = get_all_documentdbs
    assert_equal(exp_documentdbs.size, act_documentdbs.size)
    assert_equal(exp_documentdbs.sort, act_documentdbs.keys.sort)
  end

  def assert_attribute_exists(attr_name)
    attr_stats = vespa.search["search"].first.get_state_v1_custom_component("/documentdb/test/subdb/ready/attribute")
    assert(attr_stats[attr_name] != nil, "Expected attribute '#{attr_name}' to exist")
  end

  def assert_attribute_not_exists(attr_name)
    attr_stats = vespa.search["search"].first.get_state_v1_custom_component("/documentdb/test/subdb/ready/attribute")
    assert(attr_stats[attr_name] == nil, "Expected attribute '#{attr_name}' not to exist")
  end

  def test_add_field
    set_description("Test that we can add attribute, summary, and index fields to a live system")
    @test_dir = selfdir + "add/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:common.configmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdb", "debug=on")
    #vespa.adminserver.logctl("searchnode:proton.server.proton", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.protonconfigurer", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.bootstrapconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigholder", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.protonconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:common.configagent", "debug=on,spam=on")

    #vespa.adminserver.logctl("searchnode:proton.server.attributeproxy", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.matching.query", "debug=on")
    #vespa.adminserver.logctl("searchnode:proton.matching.querynodes", "debug=on")

    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    assert_attribute_not_exists("f2")
    assert_attribute_not_exists("f3")

    puts "1.0: add attribute"
    redeploy("test.1.sd")
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.1.json", "documentid")
    assert_hitcount("f2:%3E20&nocache", 1)
    assert_relevancy("sddocname:test&nocache&ranking=rp1", 21, 0)
    assert_relevancy("sddocname:test&nocache&ranking=rp1",  0, 1)
    assert_xml_result_with_timeout(2.0, "f2:%3E20&nocache&ranking=rp1&select=all(group(f2) each(output(count())))&hits=0", @test_dir + "grouping.xml")
    assert_attribute_exists("f2")
    assert_attribute_not_exists("f3")

    puts "1.1: add attribute & summary"
    redeploy("test.2.sd")
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.2.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.2.json", "documentid")
    assert_hitcount("f2:%3E20&nocache", 2)
    assert_hitcount("f3:%3E30&nocache", 1)
    assert_attribute_exists("f2")
    assert_attribute_exists("f3")

    puts "2.0: add summary"
    redeploy("test.3.sd")
    feed_and_wait_for_docs("test", 4, :file => @test_dir + "feed.3.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.3.json", "documentid")
    assert_hitcount("f4:f43&nocache", 0)

    puts "3.0: add index"
    redeploy("test.4.sd")
    feed_and_wait_for_docs("test", 5, :file => @test_dir + "feed.4.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.4.json", "documentid")
    assert_hitcount("f5:e&nocache", 1)

    puts "3.1: add index & summary"
    redeploy("test.5.sd")
    feed_and_wait_for_docs("test", 6, :file => @test_dir + "feed.5.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.5.json", "documentid")
    assert_hitcount("f5:f5&nocache", 2)
    assert_hitcount("f6:f&nocache", 1)
    assert_hitcount("f&nocache", 2)

    restart_proton("test", 6);
    assert_result("sddocname:test&nocache", @test_dir + "result.5.json", "documentid")
    assert_hitcount("f2:%3E20&nocache", 5)
    assert_hitcount("f3:%3E30&nocache", 4)
    assert_hitcount("f4:f43&nocache", 0)
    assert_hitcount("f5:e&nocache", 1)
    assert_hitcount("f5:f5&nocache", 2)
    assert_hitcount("f6:f&nocache", 1)
    assert_hitcount("f&nocache", 2)
  end

  def test_remove_field
    set_description("Test that we can remove attribute, summary, and index fields in a live system")
    @test_dir = selfdir + "add/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.5.sd")))
    start
    postdeploy_wait(deploy_output)
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.proton", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.protonconfigurer", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.fast_access_doc_subdb", "debug=on")
    #vespa.adminserver.logctl("searchnode:proton.server.metricsengine", "debug=on")

    feed_and_wait_for_docs("test", 1, :file => selfdir + "add/feed.5.json")
    assert_result("sddocname:test&nocache", selfdir + "remove/result.5.json", "documentid")
    assert_hitcount("f6:f&nocache", 1)
    assert_hitcount("f6&nocache", 1)

    puts "remove index & summary field (f6)"
    redeploy("test.4.sd")
    feed_and_wait_for_docs("test", 2, :file => selfdir + "add/feed.4.json")
    assert_result("sddocname:test&nocache", selfdir + "remove/result.4.json", "documentid")
    assert_hitcount("f6:f&nocache", 0)
    assert_hitcount("f6&nocache", 0)
    assert_hitcount("f5:e&nocache", 1)

    puts "remove index field (f5)"
    redeploy("test.3.sd")
    feed_and_wait_for_docs("test", 3, :file => selfdir + "add/feed.3.json")
    assert_result("sddocname:test&nocache", selfdir + "remove/result.3.json", "documentid")
    assert_hitcount("f5:e&nocache", 0)

    puts "remove summary field (f4)"
    redeploy("test.2.sd")
    feed_and_wait_for_docs("test", 4, :file => selfdir + "add/feed.2.json")
    assert_result("sddocname:test&nocache", selfdir + "remove/result.2.json", "documentid")
    assert_hitcount("f3:%3E30&nocache", 4)
    assert_attributes_exist(["f2", "f3"])

    puts "remove attribute & summary field (f3)"
    redeploy("test.1.sd")
    feed_and_wait_for_docs("test", 5, :file => selfdir + "add/feed.1.json")
    assert_result("sddocname:test&nocache", selfdir + "remove/result.1.json", "documentid")
    assert_hitcount("f3:%3E30&nocache", 0)
    assert_hitcount("f2:%3E20&nocache", 5)
    assert_attributes_exist(["f2"])

    puts "remove attribute field (f2)"
    redeploy("test.0.sd")
    feed_and_wait_for_docs("test", 6, :file => selfdir + "add/feed.0.json")
    assert_result("sddocname:test&nocache", selfdir + "remove/result.0.json", "documentid")
    assert_hitcount("f2:%3E20&nocache", 0)
    assert_attributes_exist([])

    restart_proton("test", 6)
    assert_result("sddocname:test&nocache", selfdir + "remove/result.0.json", "documentid")
    assert_hitcount("f2:%3E20&nocache", 0)
    assert_hitcount("f3:%3E30&nocache", 0)
    assert_hitcount("f5:e&nocache", 0)
    assert_hitcount("f6:f&nocache", 0)
    assert_hitcount("f6&nocache", 0)
  end

  def test_documentdb_addition_and_removal
    set_description("Test that document databases can be added and removed")
    @test_dir = selfdir + "docdb/"
    deploy_output = deploy_app(SearchApp.new.sd(@test_dir + "testa.sd"))
    start
    postdeploy_wait(deploy_output)
    enable_proton_debug_log
    #vespa.adminserver.logctl("searchnode:proton.server.proton_config_fetcher", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.bootstrapconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("searchnode:proton.server.documentdbconfigmanager", "debug=on,spam=on")
    #vespa.adminserver.logctl("configproxy:com.yahoo.vespa.config.proxy.ConfigProxyRpcServer", "debug=on")
    feed_and_wait_for_docs("testa", 1, :file => @test_dir + "feed.0.json")
    assert_documentdbs_exist(["testa"])

    puts "add 'testb' documentdb"
    deploy_output = deploy_app(SearchApp.new.sd(@test_dir + "testa.sd").sd(@test_dir + "testb.sd"))
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    #vespa.adminserver.execute("vespa-configproxy-cmd -m cache")
    feed_and_wait_for_docs("testb", 1, :file => @test_dir + "feed.1.json")
    assert_hitcount("d&nocache", 2)
    assert_result("d&nocache", @test_dir + "result.0.json", "documentid")
    assert_hitcount("f2:d&nocache", 1)
    assert_hitcount("f3:%3E29&nocache", 2)
    assert_documentdbs_exist(["testa", "testb"])

    puts "remove 'testb' documentdb"
    deploy_output = deploy_app(SearchApp.new.sd(@test_dir + "testa.sd").
                               validation_override("content-type-removal"))
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    wait_for_hitcount("d&nocache", 1)
    assert_result("d&nocache", @test_dir + "result.1.json", "documentid")
    assert_hitcount("f2:d&nocache", 0)
    assert_hitcount("f3:%3E29&nocache", 1)
    assert_documentdbs_exist(["testa"])

    puts "feed new 'testa' docs"
    feed_and_wait_for_docs("testa", 2, :file => @test_dir + "feed.2.json")
    assert_hitcount("d&nocache", 2)
    assert_result("d&nocache", @test_dir + "result.2.json", "documentid")
    assert_hitcount("f2:d&nocache", 0)
    assert_hitcount("f3:%3E29&nocache", 2)

    puts "re-add 'testb' documentdb"
    deploy_output = deploy_app(SearchApp.new.sd(@test_dir + "testa.sd").sd(@test_dir + "testb.sd"))
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    wait_for_hitcount("d&nocache", 2)
    assert_result("d&nocache", @test_dir + "result.2.json", "documentid")
    assert_hitcount("f2:d&nocache", 0)
    assert_hitcount("f3:%3E29&nocache", 2)

    puts "feed new 'testb' docs"
    feed_and_wait_for_docs("testb", 1, :file => @test_dir + "feed.3.json")
    assert_hitcount("d&nocache", 3)
    assert_result("d&nocache", @test_dir + "result.4.json", "documentid")
    assert_hitcount("f2:d&nocache", 1)
    assert_hitcount("f3:%3E29&nocache", 3)
  end

  def test_toggle_summary
    set_description("Test")
    @test_dir = selfdir + "toggle_summary/"
    exp_logged = 
      Regexp.union(/proton\.server\.configvalidator.*Cannot add index field `f2', it has existed as a field before/,
                   /proton\.server\.documentdb.*Cannot apply new config snapshot, new schema is in conflict with old schema or history/)
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    assert_result("sddocname:test&nocache",
                  @test_dir + "result.0.json")
    puts "remove summary aspect for f2"
    redeploy("test.1.sd")
    assert_result("sddocname:test&nocache",
                  @test_dir + "result.0b.json")
    puts "readd summary aspect for f2"
    redeploy("test.0.sd")
    assert_hitcount("f1:b&nocache", 1)
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    assert_hitcount("f1:b&nocache", 2)
    assert_hitcount("f2:%3E19&nocache", 2)
    assert_result("sddocname:test&nocache", @test_dir + "result.1a.json")

    puts "use new config again"
    redeploy("test.1.sd")
    assert_result("sddocname:test&nocache", @test_dir + "result.1.json")
    assert_hitcount("f1:b&nocache", 2)
    assert_hitcount("f2:%3E19&nocache", 2)
    puts "add attribute to rank profile"
    redeploy("test.2.sd")
    assert_result("sddocname:test&nocache", @test_dir + "result.1.json")
    assert_hitcount("f1:b&nocache", 2)
    assert_hitcount("f2:%3E19&nocache", 2)
  end

  def test_validation_upon_restart_does_not_reject
    set_description("Test that validation upon proton restart does not reject persisted config")
    @test_dir = selfdir + "toggle_summary/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    puts "remove summary aspect for f2"
    redeploy("test.1.sd")
    assert_result("sddocname:test&nocache", @test_dir + "result.0b.json")

    # Verify that validation upon restart do not reject the summary removal for f2.
    vespa.search["search"].first.trigger_flush
    restart_proton("test", 1)
    assert_result("sddocname:test&nocache", @test_dir + "result.0b.json")
  end

  def test_remove_attribute_aspect_from_index_field
    set_description("Test that we can remove attribute aspect from an existing index field without any actions")
    @test_dir = selfdir + "remove_attribute_from_index/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.0.json")

    # Feed partial updates to f1
    feed(:file => @test_dir + "update.0.json")
    assert_hitcount("f1:foo&nocache", 0)
    assert_hitcount("f1:bar&nocache", 2)

    puts "remove attribute aspect from f1 (still an index field)"
    deploy_output = redeploy("test.1.sd")
    puts "deploy output: '#{deploy_output}'"
    assert_hitcount("f1:foo&nocache", 0)
    assert_hitcount("f1:bar&nocache", 2)
    assert_result("query=sddocname:test&nocache", @test_dir + "test.0.result.json", "documentid")
    assert_log_not_matches(/Cannot apply new config snapshot directly/)
    assert_no_match(/Field 'f1' changed: remove attribute aspect/, deploy_output)

    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.1.json")
    assert_hitcount("f1:foo&nocache", 0)
    assert_hitcount("f1:bar&nocache", 3)
  end

  def teardown
    stop
  end

end
