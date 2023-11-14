# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'rexml/document'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesStructAttribute < SearchTest

  include SchemaChangesBase

  def setup
    set_owner("toregge")
  end

  def timeout_seconds
    1800
  end

  def assert_add_attribute_hitcount(f1_cnt, f2_cnt)
    assert_hitcount("yql=select %2a from sources %2a where elem_array contains sameElement(f1 contains \"foo\")", f1_cnt)
    assert_hitcount("yql=select %2a from sources %2a where elem_array contains sameElement(f2 contains \"bar\")", f2_cnt)
  end

  def assert_remove_attribute_hitcount(f1_foocnt, f1_bazcnt, f2_barcnt, f2_baycnt)
    assert_hitcount("yql=select %2a from sources %2a where elem_array contains sameElement(f1 contains \"foo\")&nocache", f1_foocnt)
    assert_hitcount("yql=select %2a from sources %2a where elem_array contains sameElement(f1 contains \"baz\")&nocache", f1_bazcnt)
    assert_hitcount("yql=select %2a from sources %2a where elem_array contains sameElement(f2 contains \"bar\")&nocache", f2_barcnt)
    assert_hitcount("yql=select %2a from sources %2a where elem_array contains sameElement(f2 contains \"bay\")&nocache", f2_baycnt)
  end

  def redeploy_no_reprocess(sd_file)
    redeploy(sd_file)
    status = vespa.search["search"].first.get_proton_status
    assert(status.match(/"OK","state=ONLINE configstate=OK",""/))
  end

  def remove_attribute_aspect(sd_file)
    redeploy_no_reprocess(sd_file)
  end

  def assert_add_reprocess_event_logs
    assert_log_matches(/.populate\.attribute\.start.*test\.0\.ready\.attribute\.elem_array\.f1/)
    assert_reprocess_event_logs
    assert_log_matches(/.populate\.attribute\.complete.*test\.0\.ready\.attribute\.elem_array\.f1.*documents\.populated":5/)
  end

  def assert_full_json_result(exp_json_result_file)
    assert_result("query=sddocname:test&nocache&format=json",
                  @test_dir + exp_json_result_file,
                  "documentid")
  end

  def test_add_attribute_aspect_to_struct_field
    set_description("Test that we can add attribute aspect on an existing struct field and that attribute is populated")
    @test_dir = selfdir + "add_struct_field_attribute/"
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
    assert_add_reprocess_event_logs
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

  def test_remove_attribute_aspect_from_struct_field
    set_description("Test that we can remove attribute aspect on an existing struct field")
    @test_dir = selfdir + "remove_struct_field_attribute/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.0.json")
    assert_full_json_result("test.0.result.json")
    assert_remove_attribute_hitcount(2, 0, 2, 0)

    # Feed partial updates to f1 and f2
    feed(:file => @test_dir + "update.1.json")

    assert_full_json_result("test.1.result.json")
    assert_remove_attribute_hitcount(0, 2, 0, 2)

    puts "Remove attribute aspect 1"
    remove_attribute_aspect("test.1.sd")
    assert_full_json_result("test.1.result.json")
    assert_remove_attribute_hitcount(0, 0, 0, 2)
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.2.json")
    assert_full_json_result("test.2.result.json")
    assert_remove_attribute_hitcount(0, 0, 1, 2)

    puts "Activate attribute aspect removed 1"
    activate_attribute_aspect(3)
    assert_full_json_result("test.2.result.json")
    assert_remove_attribute_hitcount(0, 0, 1, 2)
    feed_and_wait_for_docs("test", 4, :file => @test_dir + "feed.3.json")
    assert_full_json_result("test.3.result.json")
    assert_remove_attribute_hitcount(0, 0, 2, 2)


    vespa.search["search"].first.trigger_flush
    puts "Remove attribute aspect 2"
    remove_attribute_aspect("test.2.sd")
    assert_full_json_result("test.3.result.json")
    assert_remove_attribute_hitcount(0, 0, 0, 0)
    feed_and_wait_for_docs("test", 5, :file => @test_dir + "feed.4.json")

    puts "Activate attribute aspect 2"
    activate_attribute_aspect(5)
    assert_full_json_result("test.4.result.json")
    assert_remove_attribute_hitcount(0, 0, 0, 0)
  end

  def check_add_and_remove_struct_field(attr_field)
    @test_dir = selfdir + "add_and_remove_struct_field/"
    attr_suffix = attr_field ? "_attr" : ""
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test#{attr_suffix}.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    assert_full_json_result("test.0.result.json")
    puts "Add field"
    redeploy_no_reprocess("test#{attr_suffix}.1.sd")
    assert_full_json_result("test.0.result.json")
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    assert_full_json_result("test.1.result.json")
    puts "Remove field"
    redeploy_no_reprocess("test#{attr_suffix}.2.sd")
    assert_full_json_result("test#{attr_suffix}.2.result.json")
  end

  def test_add_and_remove_attr_struct_field
    set_description("Test that we can add and remove struct fields with attribute aspect")
    check_add_and_remove_struct_field(true)
  end

  def test_add_and_remove_struct_field
    set_description("Test that we can add and remove struct fields without attribute aspect")
    check_add_and_remove_struct_field(false)
  end

  def teardown
    stop
  end

end
