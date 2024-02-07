# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_only_test'

class ParentChildFeedTest < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    @test_dir = selfdir + "parent_child_feed/"
  end

  def test_put_update_summary_of_reference_fields
    set_description("Test feeding (put and update) and document summary of reference fields")
    deploy_app(SearchApp.new.sd(@test_dir + "campaign.sd", { :global => true }).sd(@test_dir + "ad.sd"))
    start
    feed_and_wait_for_docs("campaign", 2, :file => @test_dir + "campaign-docs.json")
    feed_and_wait_for_docs("ad", 5, :file => @test_dir + "ad-docs.json")
    assert_campaign_ref_fields(["id:test:campaign::the-best",
                                "id:test:campaign::next-best",
                                "id:test:campaign::not-here",
                                nil, nil])

    feed(:file => @test_dir + "ad-updates.json")
    assert_campaign_ref_fields([nil, nil,
                                "id:test:campaign::the-best",
                                "id:test:campaign::next-best",
                                "id:test:campaign::not-here"])

    feed(:file => @test_dir + "ad-docs.json")
    assert_campaign_ref_fields(["id:test:campaign::the-best",
                                "id:test:campaign::next-best",
                                "id:test:campaign::not-here",
                                nil, nil])

    feed_and_assert_that_invalid_reference_docid_fails
    assert_campaign_ref_fields(["id:test:campaign::the-best",
                                "id:test:campaign::next-best",
                                "id:test:campaign::not-here",
                                nil, nil])

  end

  def feed_and_assert_that_invalid_reference_docid_fails
    feed_output = feed(:file => @test_dir + "ad-doc.invalid.json", :exceptiononfailure => false, :stderr => true)
    assert_match(Regexp.new(/Can't assign document ID 'id:test:invalid::0'/), feed_output)
  end

  def assert_campaign_ref_fields(exp_campaign_refs)
    result = search("query=sddocname:ad&presentation.format=json")
    result.sort_results_by("documentid")
    assert_equal(result.hitcount, exp_campaign_refs.size)
    for i in 0...exp_campaign_refs.size do
      exp_value = exp_campaign_refs[i]
      act_value = result.hit[i].field["campaign_ref"]
      puts "#{i}: '#{exp_value}' == '#{act_value}' ?"
      assert_equal(exp_value, act_value)
    end
  end

  def teardown
    stop
  end

end
