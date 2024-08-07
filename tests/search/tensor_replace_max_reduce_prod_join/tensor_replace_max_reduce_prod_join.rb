# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class TensorReplaceMaxReduceProdJoinTest < IndexedOnlySearchTest

  def setup
    set_owner("lesters")
  end

  def teardown
    stop
  end

  def test_replace_max_reduce_prod_join_expression
    set_description("Test cases where the max-reduce-prod-join tensor expression is or is not replaced")
    deploy_and_feed
    verify_rank_profiles
  end

  def deploy_and_feed
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").sd(selfdir + "parent.sd", { :global => true }))
    start
    feed_and_wait_for_docs("parent", 3, :file => selfdir + "parent-docs.json")
    feed_and_wait_for_docs("test", 3, :file => selfdir + "test-docs.json")
    @log = read_log_from_logserver
  end

  def verify_rank_profiles
    verify_rank_profile(true,  "longarray")
    verify_rank_profile(true,  "intarray")
    verify_rank_profile(true,  "argument_reorder")
    verify_rank_profile(true,  "parentarray")
    verify_rank_profile(true,  "fs_longarray")
    verify_rank_profile(false, "div")
    verify_rank_profile(false, "stringarray")

    verify_rank_profile(false, "long", true)
  end

  def verify_rank_profile(should_replace, rank_profile, verify_results = true)
    output "Verifying rank profile #{rank_profile}..."

    log_message_if_replaced = /rankingExpression\(#{rank_profile}_expr\) replaced with internalMaxReduceProdJoin/i
    assert_equal(should_replace, log_message_if_replaced.match(@log) != nil)

    if verify_results
      result = search("query=sddocname:test&rankproperty.weights={1111:1234,2222:2245}&ranking=#{rank_profile}")
      assert_equal(3, result.hit.size)

      assert_equal(1, result.hit[0].field["id"].to_i)
      assert_equal(0, result.hit[1].field["id"].to_i)
      assert_equal(2, result.hit[2].field["id"].to_i)

      assert_equal(0.2245, result.hit[0].field["relevancy"].to_f)
      assert_equal(0.1234, result.hit[1].field["relevancy"].to_f)
      assert_equal(0.0, result.hit[2].field["relevancy"].to_f)
    end
  end

end
