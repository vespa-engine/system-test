# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class GlobalParentsFeedTest < SearchTest

  def setup
    set_owner("geirst")
    @test_dir = selfdir + "global_parents_feed/"
  end

  def make_app
    # TODO: Remove config override when new functionality is added to distributor
    SearchApp.new.
      sd(@test_dir + "campaign.sd", { :global => true }).
      sd(@test_dir + "ad.sd").
      cluster_name("my_cluster").
      redundancy(2).
      num_parts(4).
      enable_document_api
  end

  def test_feeding_and_redistribution_of_global_parents
    set_description("Test feeding (put, update, remove) and redistribution of global parents")
    deploy_app(make_app)
    @campaigns = {}
    @campaign_ad_mapping = {}
    start
    vespa.stop_content_node("my_cluster", "3")

    update_expected({ campaign(1) => budget(10),
                      campaign(2) => budget(20),
                      campaign(3) => budget(30),
                      campaign(4) => budget(40),
                      campaign(5) => budget(50),
                      campaign(6) => budget(60),
                      campaign(7) => budget(70) },
                    { budget(10) => ads(1..5),
                      budget(20) => ads(6..10),
                      budget(30) => ads(11..15),
                      budget(40) => ads(16..20),
                      budget(50) => ads(21..25),
                      budget(60) => ads(26..30),
                      budget(70) => ads(31..35) })
    feed_and_validate_first_time("campaign-batch-1-7.json")


    update_expected({ campaign(1) => budget(11) },
                    { budget(10) => Set.new,
                      budget(11) => ads(1..5) })
    feed_and_validate("campaign-update.json")


    update_expected({ campaign(2) => removed(20) },
                    { budget(20) => Set.new })
    feed_and_validate("campaign-remove.json")


    start_node_and_wait("my_cluster", 3)
    validate_corpus
    update_expected({ campaign(8) => budget(80) },
                    { budget(80) => ads(36..40) })
    feed_and_validate("campaign-batch-8.json")


    stop_node_and_wait("my_cluster", 0)
    validate_corpus
    update_expected({ campaign(9) => budget(90) },
                    { budget(90) => ads(41..45) })
    feed_and_validate("campaign-batch-9.json")
  end

  def update_expected(campaigns, campaign_ad_mapping)
    @campaigns.merge!(campaigns)
    @campaign_ad_mapping.merge!(campaign_ad_mapping)
  end

  def feed_and_validate_first_time(feed_file)
    feed_and_validate(feed_file, true)
  end

  def feed_and_validate(feed_file, first_time=false)
    feed(:file => @test_dir + feed_file)
    wait_for_atleast_hitcount("sddocname:ad", 1) if first_time
    validate_corpus
  end

  def validate_corpus
    assert_campaigns(@campaigns)
    assert_campaign_ad_mapping(@campaign_ad_mapping)
  end

  def assert_campaigns(exp_campaigns)
    exp_campaigns.each do |doc_id, budget|
      if budget.is_a?(Removed)
        assert_removed_campaign(doc_id, budget.value)
      else
        assert_campaign_with_query(doc_id, budget)
        assert_campaign_with_get(doc_id, budget)
      end
    end
  end

  def assert_campaign_with_query(doc_id, budget)
    query = query_budget(budget)
    log(:assert_campaign_with_query, doc_id, budget, query)
    result = search(query)
    assert_hitcount(result, 1)
    assert_equal(doc_id.dup, result.hit[0].field['documentid'])
    assert_equal(budget, result.hit[0].field['budget'])
  end

  def assert_campaign_with_get(doc_id, budget)
    doc = vespa.document_api_v1.get(doc_id)
    assert_equal(budget.to_s, doc.fields["budget"].to_s)
  end

  def assert_removed_campaign(doc_id, budget)
    query = query_budget(budget)
    log(:assert_removed_campaign, doc_id, budget, query)
    assert_hitcount(query, 0)
    doc = vespa.document_api_v1.get(doc_id)
    assert(doc == nil)
  end

  def assert_campaign_ad_mapping(exp_budgets_to_ads)
    exp_budgets_to_ads.each do |budget, ad_ids|
      assert_ads_for_budget(budget, ad_ids)
    end
  end

  def assert_ads_for_budget(budget, ad_ids)
    query = query_ad_budget(budget)
    log(:assert_ads_for_budget, budget, ad_ids.inspect, query)
    result = search(query)
    assert_hitcount(result, ad_ids.size)
    assert_equal(ad_ids, extract_ids_from_result(result))
  end

  def extract_ids_from_result(result)
    result.hit.map {|hit| hit.field["documentid"] }.to_set
  end

  def campaign(id)
    "id:test:campaign::#{id}"
  end

  def ad(id)
    "id:test:ad::#{id}"
  end

  def ads(ids)
    ids.map {|id| ad(id) }.to_set
  end

  def budget(value)
    value
  end

  Removed = Struct.new(:value)

  def removed(value)
    Removed.new(value)
  end

  def query_budget(budget)
    "query=budget:#{budget}"
  end

  def query_ad_budget(budget)
    "query=ad_budget:#{budget}"
  end

  def log(func, *args)
    puts "#{func}(#{args.join(', ')})"
  end

  def teardown
    stop
  end

end
