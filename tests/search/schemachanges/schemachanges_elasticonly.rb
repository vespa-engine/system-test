# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'rexml/document'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesElastic < IndexedSearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  def timeout_seconds
    1800
  end

  def self.testparameters
    { "ELASTIC" => { :search_type => "ELASTIC"} }
  end

  def test_get_after_new_doctype
    set_description("Test that get works with new document types in elastic mode")
    @test_dir = selfdir + "docdb/"
    deploy_output = deploy_app(SearchApp.new.
                               sd(@test_dir + "testa.sd").
                               container(Container.new.
                                           documentapi(ContainerDocumentApi.new).
                                           search(Searching.new)))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("testa", 1, :file => @test_dir + "feed.0.xml")

    puts "add 'testb' documentdb"
    deploy_output = deploy_app(SearchApp.new.
                                 sd(@test_dir + "testa.sd").sd(@test_dir + "testb.sd").
                                 container(Container.new.
                                             documentapi(ContainerDocumentApi.new).
                                             search(Searching.new)))

    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)

    feed_output = feed(:file => @test_dir + "feed.1.xml")
    wait_for_get_result("id:testb:testb::1", Document.new("testb", "id:testb:testb::1").add_field("f2", "b c d e").add_field("f3", 31))
  end

  def test_document_db_removal_bucketinfo
    set_description("Test that document db removal updates bucket info")
    @test_dir = selfdir + "docdb/"
    deploy_output = deploy_app(get_app(2))
    start
    postdeploy_wait(deploy_output)
    feed(:file => @test_dir + "feed.10.xml")
    feed(:file => @test_dir + "feed.11.xml")
    assert_hitcount(hcs("testa"), 1)
    assert_hitcount(hcs("testb"), 1)
    buckets = get_buckets
    assert_equal(1, buckets.size, "Unexpected number of buckets")
    assert_equal(2, bucket_sum(buckets), "Unexpected number of bucketed docs")
    deploy_output = deploy_app(get_app(1))
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    buckets = get_buckets
    assert_equal(1, buckets.size, "Unexpected number of buckets")
    assert_equal(1, bucket_sum(buckets), "Unexpected number of bucketed docs")
  end

  def test_document_db_propagate_active_buckets
    set_description("Test that document db addition propagates active buckets")
    @test_dir = selfdir + "docdb/"
    deploy_output = deploy_app(get_app(1))
    start
    postdeploy_wait(deploy_output)
    enable_proton_debug_log(0)
    feed(:file => @test_dir + "feed.10.xml")
    assert_hitcount(hcs("testa"), 1)
    deploy_output = deploy_app(get_app(2))
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    sleep 4
    feed(:file => @test_dir + "feed.11.xml")
    assert_hitcount(hcs("testb"), 1)
  end

  def assert_add_attribute_hitcount(f1_cnt, f2_cnt)
    assert_hitcount("f1:foo", f1_cnt)
    assert_hitcount("f2:bar", f2_cnt)
  end

  def assert_remove_attribute_hitcount(f1_foocnt, f1_bazcnt, f2_barcnt, f2_baycnt)
    assert_hitcount("f1:foo&nocache", f1_foocnt)
    assert_hitcount("f1:baz&nocache", f1_bazcnt)
    assert_hitcount("f2:bar&nocache", f2_barcnt)
    assert_hitcount("f2:bay&nocache", f2_baycnt)
  end

  def test_add_attribute_aspect
    set_description("Test that we can add attribute aspect on an existing field and that attribute is populated")
    @test_dir = selfdir + "add_attribute/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.0.json")
    assert_add_attribute_hitcount(0, 0)

    puts "Add attribute aspect 1"
    add_attribute_aspect("test.1.sd")
    assert_add_attribute_hitcount(0, 0)
    feed_and_wait_for_docs("test", 5, :file => @test_dir + "feed.1.json")
    assert_add_attribute_hitcount(0, 0)

    puts "Activate attribute aspect 1"
    activate_attribute_aspect(5)
    assert_add_attribute_hitcount(5, 0)
    assert_add_reprocess_event_logs("f1", 5)
    feed_and_wait_for_docs("test", 7, :file => @test_dir + "feed.2.json")
    assert_add_attribute_hitcount(7, 0)

    vespa.search["search"].first.trigger_flush
    puts "Add attribute aspect 2"
    add_attribute_aspect("test.2.sd")
    assert_add_attribute_hitcount(7, 0)
    feed_and_wait_for_docs("test", 9, :file => @test_dir + "feed.3.json")
    assert_add_attribute_hitcount(9, 0)

    puts "Activate attribute aspect 2"
    activate_attribute_aspect(9)
    assert_add_attribute_hitcount(9, 9)
  end

  def test_remove_attribute_aspect
    set_description("Test that we can remove attribute aspect on an existing field and that document store is populated")
    @test_dir = selfdir + "remove_attribute/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.0.json")
    assert_result("query=sddocname:test&nocache",
                  @test_dir + "test.0.result.json",
                  "documentid")
    assert_remove_attribute_hitcount(2, 0, 2, 0)

    # Feed partial updates to f1, f2 and f3
    feed(:file => @test_dir + "update.1.xml")

    assert_result("query=sddocname:test&nocache",
                  @test_dir + "test.1.result.json",
                  "documentid")
    assert_remove_attribute_hitcount(0, 2, 0, 2)

    puts "Remove attribute aspect 1"
    remove_attribute_aspect("test.1.sd")
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.2.json")
    assert_result("query=sddocname:test&nocache",
                  @test_dir + "test.2.result.json",
                  "documentid")
    assert_remove_attribute_hitcount(0, 0, 1, 2)

    puts "Activate attribute aspect removed 1"
    activate_attribute_aspect(3)
    assert_remove_reprocess_event_logs("f1", 3)
    feed_and_wait_for_docs("test", 4, :file => @test_dir + "feed.3.json")
    assert_result("query=sddocname:test&nocache",
                  @test_dir + "test.3.result.json",
                  "documentid")
    assert_remove_attribute_hitcount(0, 0, 2, 2)


    vespa.search["search"].first.trigger_flush
    puts "Remove attribute aspect 2"
    remove_attribute_aspect("test.2.sd")
    feed_and_wait_for_docs("test", 5, :file => @test_dir + "feed.4.json")

    puts "Activate attribute aspect 2"
    activate_attribute_aspect(5)
    assert_result("query=sddocname:test&nocache",
                  @test_dir + "test.4.result.json",
                  "documentid")
    assert_remove_attribute_hitcount(0, 0, 0, 0)
  end

  def hcs(doctype)
    "/search/?query=sddocname:#{doctype}&nocache&hits=0&ranking=unranked"
  end

  def get_buckets
    cluster = vespa.storage["search"]
    cluster_state = cluster.get_cluster_state
    storage_state = cluster.gather_storagenode_bucket_databases(cluster_state)
    storage_state['default'][0]
  end

  def bucket_sum(buckets)
    docs = 0
    buckets.each do |bucket, bi|
      docs += bi.docs
    end
    docs 
  end

  def get_app(doctypes)
    app = SearchApp.new.sd(@test_dir + "testa.sd").
                        validation_override("content-type-removal")
    if (doctypes > 1)
      app.sd(@test_dir + "testb.sd")
    end
    app
  end

  def enable_proton_debug_log(index)
    proton = vespa.search["search"].searchnode[index]
    proton.logctl2("proton.server.storeonlyfeedview", "all=on")
    proton.logctl2("proton.persistenceengine.persistenceengine", "all=on")
    proton.logctl2("proton.server.buckethandler", "all=on")
  end

  def wait_for_get_result(doc_id, expected_doc)
    actual_doc = nil
    30.times do
      actual_doc = vespa.document_api_v1.get(doc_id, :port => Environment.instance.vespa_web_service_port)
      puts "doc: '#{actual_doc}'"
      if expected_doc != actual_doc
        sleep 1
      else
        break
      end
    end
    assert_equal(expected_doc, actual_doc)
  end

  def teardown
    stop
  end

end
