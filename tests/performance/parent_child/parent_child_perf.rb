# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/parent_child/utils/data_generator'
require 'pp'

class ParentChildPerfTest < PerformanceTest

  FBENCH_RUNTIME = 30
  MODE = "mode"
  FEEDING_PUT = "feeding_put"
  FEEDING_UPDATE = "feeding_update"
  RANKING = "ranking"
  MATCHING = "matching"
  CAMPAIGN_AD_RATIO = "campaign_ad_ratio"
  ADVERTISER_CAMPAIGN_RATIO = "advertiser_campaign_ratio"
  FIELD_TYPE = "field_type"
  IMPORTED = "imported"
  IMPORTED_NESTED = "imported_nested"
  FLATTENED = "flattened"
  MATCH_TYPE = "match_type"
  FAST = "fast"
  SLOW = "slow"

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
    @first_run = true
    @num_ad_docs = 2000000
  end

  def feeder_binary
    # TODO Duration of the feed tests should be increased so that feedclient startup cost does not matter.
    "vespa-feeder"
  end

  def test_parent_child_feeding_ranking_matching
    set_description("Test performance of parent child feeding (partial updates), ranking and matching")
    [[1,10],[10,1],[1000,1]].each do |ratios|
      clean_indexes_and_deploy_app
      run_tests(@num_ad_docs, ratios[0], ratios[1])
    end
  end

  def clean_indexes_and_deploy_app
    if !@first_run
      vespa.stop_base
      vespa.adminserver.clean_indexes
    end
    deploy_app(create_app)
    start
    @container = vespa.container.values.first
    @first_run = false
  end

  def create_app
    SearchApp.new.sd(selfdir + "advertiser.sd", { :global => true }).
                  sd(selfdir + "campaign.sd", { :global => true }).
                  sd(selfdir + "ad.sd").
                  threads_per_search(1).
                  search_dir(selfdir + "search").
                  container(Container.new("combinedcontainer").
                            jvmoptions('-Xms16g -Xmx16g').
                            search(Searching.new).
                            docproc(DocumentProcessing.new).
                            documentapi(ContainerDocumentApi.new)).
                  indexing("combinedcontainer")
  end

  def run_tests(num_ad_docs, campaign_ad_ratio, advertiser_campaign_ratio)
    data = ParentChildDataGenerator.new(num_ad_docs, campaign_ad_ratio, advertiser_campaign_ratio, dirs.tmpdir)
    feed(:file => data.ad_docs)

    feed_and_profile(data.campaign_docs, FEEDING_PUT, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED, SLOW)
    feed_and_profile(data.campaign_updates, FEEDING_UPDATE, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED, SLOW)
    feed_and_profile(data.ad_updates, FEEDING_UPDATE, campaign_ad_ratio, advertiser_campaign_ratio, FLATTENED, SLOW)
    feed(:file => data.advertiser_docs)

    fbench_and_profile(data.ranking_queries, RANKING, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED, SLOW, "&ranking=imported_budget")
    fbench_and_profile(data.ranking_queries, RANKING, campaign_ad_ratio, advertiser_campaign_ratio, FLATTENED, SLOW, "&ranking=flattened_budget")
    if is_grandparent_test_case(campaign_ad_ratio)
      fbench_and_profile(data.ranking_queries, RANKING, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED_NESTED, FAST, "&ranking=imported_root_budget")
    end

    fbench_and_profile(data.imported_budget_slow_queries, MATCHING, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED, SLOW, "")
    fbench_and_profile(data.imported_budget_fast_queries, MATCHING, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED, FAST, "")
    fbench_and_profile(data.flattened_budget_slow_queries, MATCHING, campaign_ad_ratio, advertiser_campaign_ratio, FLATTENED, SLOW, "")
    fbench_and_profile(data.flattened_budget_fast_queries, MATCHING, campaign_ad_ratio, advertiser_campaign_ratio, FLATTENED, FAST, "")
    if is_grandparent_test_case(campaign_ad_ratio)
      fbench_and_profile(data.imported_root_budget_fast_queries, MATCHING, campaign_ad_ratio, advertiser_campaign_ratio, IMPORTED_NESTED, FAST, "")
    end
  end

  def is_grandparent_test_case(campaign_ad_ratio)
    [1, 10].include? campaign_ad_ratio
  end

  def feed_and_profile(feed_file, mode, campaign_ad_ratio, advertiser_campaign_ratio, field_type, match_type)
    profiler_start
    fillers = [parameter_filler(MODE, mode),
               parameter_filler(CAMPAIGN_AD_RATIO, campaign_ad_ratio),
               parameter_filler(ADVERTISER_CAMPAIGN_RATIO, advertiser_campaign_ratio),
               parameter_filler(FIELD_TYPE, field_type),
               parameter_filler(MATCH_TYPE, match_type)]
    run_feeder(feed_file, fillers)
    profiler_report(profiler_label(mode, campaign_ad_ratio, advertiser_campaign_ratio, field_type, match_type))
  end

  def profiler_label(mode, campaign_ad_ratio, advertiser_campaign_ratio, field_type, match_type)
    "#{MODE}=#{mode}.#{CAMPAIGN_AD_RATIO}=#{campaign_ad_ratio}.#{ADVERTISER_CAMPAIGN_RATIO}=#{advertiser_campaign_ratio}.#{FIELD_TYPE}=#{field_type}.#{MATCH_TYPE}=#{match_type}"
  end

  def fbench_and_profile(query_file, mode, campaign_ad_ratio, advertiser_campaign_ratio, field_type, match_type, append_str)
    copy_query_file(query_file)
    fillers = [parameter_filler(MODE, mode),
               parameter_filler(CAMPAIGN_AD_RATIO, campaign_ad_ratio),
               parameter_filler(ADVERTISER_CAMPAIGN_RATIO, advertiser_campaign_ratio),
               parameter_filler(FIELD_TYPE, field_type),
               parameter_filler(MATCH_TYPE, match_type)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_RUNTIME, :clients => 1, :append_str => append_str},
                fillers)
    profiler_report(profiler_label(mode, campaign_ad_ratio, advertiser_campaign_ratio, field_type, match_type))
  end

  def copy_query_file(query_file)
    @container.copy(query_file, File.dirname(query_file))
  end

  def teardown
    super
  end

end
