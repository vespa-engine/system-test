# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesWeightedSetParams < IndexedSearchTest

  include SchemaChangesBase

  def setup
    set_owner("toregge")
  end

  def test_change_weighted_set_params
    set_description("Test that existing data becomes unavailable when changing weighted set parameters for weighted set of string")
    @test_dir = selfdir + "weightedsetparams/"
    deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    proton = vespa.search["search"].first
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    puts "removing field f1"
    redeploy("test.1.sd")
    puts "adding field f1 with create-if-nonexistent param"
    redeploy("test.2.sd")
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.0.json")
    puts "removing field f1"
    redeploy("test.1.sd")
    puts "adding field f1 with create-if-nonexistent and remove-if-zero params"
    redeploy("test.3.sd")
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.2.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.1.json")
  end

  def teardown
    stop
  end

end
