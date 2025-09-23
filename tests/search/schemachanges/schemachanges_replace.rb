# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesReplaceTest < IndexedOnlySearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  def test_replace
    set_description("Test that attribute and index fields can come back with new data types")
    @test_dir = selfdir + "replace/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    proton = vespa.search["search"].first
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")

    puts "remove f2 & f3"
    redeploy("test.1.sd")
    wait_for_hitcount("f2:b&nocache", 0)

    puts "re-add f2 & f3 with new data types"
    redeploy("test.2.sd")
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    assert_hitcount("f2:b&nocache", 0)
    assert_hitcount("f3:30&nocache", 0)
    assert_hitcount("f2:d&nocache", 1)
    assert_hitcount("f3:31&nocache", 1)
    assert_result("sddocname:test&nocache", @test_dir + "result.0.json")
  end

  def test_replace_and_replay
    set_description("Test that attribute replace works with replay")
    @test_dir = selfdir + "replace_and_replay/"
    # i.e. verify that serial number check stops attribute updates before
    # type mismatch is an issue when replaying portions of transaction log
    # with old type for an attribute that has been flushed to disk
    # with new data type.
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    proton = vespa.search["search"].first
    # proton.logctl("searchnode:proton.server.attributeproxy", "all=on")
    # proton.logctl("searchnode", "all=on")
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")

    assert_hitcount("f2:b&nocache", 1)
    assert_hitcount("f3:30&nocache", 1)
    assert_hitcount("f2:31&nocache", 0)
    assert_hitcount("f3:d&nocache", 0)
    puts "remove f2 & f3"
    redeploy("test.1.sd")
    wait_for_hitcount("f2:b&nocache", 0)

    puts "re-add f2 & f3 with new data types"
    redeploy("test.2.sd")
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    assert_hitcount("f2:b&nocache", 0)
    assert_hitcount("f3:30&nocache", 0)
    assert_hitcount("f2:31&nocache", 1)
    assert_hitcount("f3:d&nocache", 1)
    assert_result("sddocname:test&nocache", @test_dir + "result.0.json")
    proton.trigger_flush
    sleep 4
    assert_hitcount("f2:b&nocache", 0)
    assert_hitcount("f3:30&nocache", 0)
    assert_hitcount("f2:31&nocache", 1)
    assert_hitcount("f3:d&nocache", 1)
    assert_result("sddocname:test&nocache", @test_dir + "result.0.json")
    proton.restart
    wait_for_hitcount("/?query=sddocname:test", 2);
    assert_hitcount("f2:b&nocache", 0)
    assert_hitcount("f3:30&nocache", 0)
    assert_hitcount("f2:31&nocache", 1)
    assert_hitcount("f3:d&nocache", 1)
    assert_result("sddocname:test&nocache", @test_dir + "result.0.json")
  end


end
