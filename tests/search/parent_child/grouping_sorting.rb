# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search/parent_child/parent_child_test_base'

class ParentChildGroupingSortingTest < ParentChildTestBase

  def setup
    set_owner('vekterli')
    @test_dir = "grouping_sorting"
  end

  def deploy_and_start
    app = SearchApp.new.sd(get_sub_test_path("campaign.sd"), { :global => true }).sd(get_test_path("ad.sd"))
    app.sd(get_sub_test_path("grandcampaign.sd"), { :global => true }) if is_grandparent_test
    deploy_app(app)
    start
  end

  def feed_baseline
    feed_and_wait_for_docs('campaign', 3, :file => get_sub_test_path("campaign-docs.json"))
    feed_and_wait_for_docs('ad', 5, :file => get_test_path("ad-docs.json"))
  end

  def teardown
    stop
  end

  def test_imported_attribute_can_be_used_for_sorting
    set_description('Test that an imported attribute can be used in a sorting expression')
    run_imported_attribute_can_be_used_for_sorting("parent")
  end

  def test_imported_grandparent_attribute_can_be_used_for_sorting
    set_description('Test that an imported grandparent attribute can be used in a sorting expression')
    run_imported_attribute_can_be_used_for_sorting("grandparent")
  end

  def run_imported_attribute_can_be_used_for_sorting(sub_test_dir)
    @sub_test_dir = sub_test_dir
    deploy_and_start
    feed_baseline

    # Asking for only 1 hit ensures the backend does the sorting
    assert_sorting('my_budget%20score', 1, 'sort_ad_parent_budget_lowest')
    assert_sorting('-my_budget%20-score', 1, 'sort_ad_parent_budget_highest')

    # Use score as secondary sorting dimension to get deterministic ordering.
    assert_sorting('my_budget%20score', 10, 'sort_ad_parent_budget_asc')
    assert_sorting('-my_budget%20-score', 10, 'sort_ad_parent_budget_desc')
  end

  def test_imported_attributes_can_be_used_for_grouping
    set_description('Test that imported attributes can be used both as grouping criteria and output')
    run_imported_attributes_can_be_used_for_grouping("parent")
  end

  def test_imported_grandparent_attributes_can_be_used_for_grouping
    set_description('Test that imported grandparent attributes can be used both as grouping criteria and output')
    run_imported_attributes_can_be_used_for_grouping("grandparent")
  end

  def run_imported_attributes_can_be_used_for_grouping(sub_test_dir)
    @sub_test_dir = sub_test_dir
    deploy_and_start
    feed_baseline

    assert_grouping('all(group(my_campaign_name) each(output(sum(my_budget))))', 'group_on_parent_name.xml')
  end

  def assert_grouping(grouping_query, file_name)
    assert_xml_result_with_timeout(2.0, "/search/?hits=0&query=sddocname:ad&select=#{grouping_query}",
                      get_test_path(file_name))
  end

  def assert_sorting(sort_spec, hits, file_name)
    assert_result("/search/?query=sddocname:ad&summary=mysummary&sortspec=#{sort_spec}&hits=#{hits}",
                  get_test_path("#{file_name}.json"))
  end

end
