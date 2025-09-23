# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'search/schemachanges/schemachanges_base'

class SchemaChangesReplayTest < IndexedOnlySearchTest

  include SchemaChangesBase

  def setup
    set_owner("geirst")
  end

  def test_replay
    set_description("Test that config from the transaction log is used during replay by removing & re-introducing fields several times")
    @test_dir = selfdir + "replay/"
    deploy_output = deploy_app(SearchApp.new.sd(use_sdfile("test.0.sd")))
    start
    postdeploy_wait(deploy_output)
    feed_and_wait_for_docs("test", 1, :file => @test_dir + "feed.0.json")
    assert_result("sddocname:test&nocache", @test_dir + "result.0.json")

    puts "re-config with test.1.sd"
    redeploy("test.1.sd")
    feed_and_wait_for_docs("test", 2, :file => @test_dir + "feed.1.json")
    replay_test_check(1, 2, "result.1.json")

    puts "re-config with test.0.sd"
    redeploy("test.0.sd")
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "feed.2.json")
    replay_test_check(0, 3, "result.2.json")

    puts "re-config with test.1.sd"
    redeploy("test.1.sd")
    feed_and_wait_for_docs("test", 4, :file => @test_dir + "feed.3.json")
    replay_test_check(1, 4, "result.3.json")
  end

  def replay_test_check(exp_hits, num_docs, result_file)
    assert_result("sddocname:test&nocache", @test_dir + result_file)
    assert_hitcount("f2:f2&nocache", exp_hits)
    assert_hitcount("f2&nocache", exp_hits)
    assert_hitcount("f3:%3E29&nocache", exp_hits)
    restart_proton("test", num_docs, skip_trigger_flush: true)
    assert_result("sddocname:test&nocache", @test_dir + result_file)
    assert_hitcount("f2:f2&nocache", exp_hits)
    assert_hitcount("f2&nocache", exp_hits)
    assert_hitcount("f3:%3E29&nocache", exp_hits)
  end


end
