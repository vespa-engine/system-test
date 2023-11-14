# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'

class FeedingAttributesPerfTest < PerformanceTest

  FEED_STAGE = "feed_stage"
  FEEDING = "feeding"
  REFEEDING = "refeeding"
  REMOVING = "removing"
  ATTRIBUTE_THREADS = "attribute_threads"

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def put_template(reorder: false)
    sequence = reorder ? '$rseq()' : '$seq()'
    wset = 1.upto(100).map { |k| "\"#{k}$ints(1, 10) is my key\": $ints(1, 100)" } .join(", ")
    fields = 1.upto(8).map { |i| "\"f#{i}\": { #{wset} }" } .join(", ")
    '{ "put": "id:test:test::' + sequence + '", "fields": { ' + fields + ' } }'
  end

  def remove_template
    '{ "remove": "id:test:test::$rseq()" }'
  end

  def test_feeding_attributes
    set_description("Test feeding performance for attribute vectors with various number of attribute write threads")
    run_test_feeding_attributes(false)
  end

  def test_feeding_paged_attributes
    set_description("Test feeding performance for paged attribute vectors with various number of attribute write threads")
    run_test_feeding_attributes(true)
  end

  def run_test_feeding_attributes(paged)
    deploy_app(get_app(1, paged))
    start

    run_feeding_attributes_test(1, { :count => 10000 })

    [4, 8].each do |attr_threads|
      clean_indexes_and_deploy_app(get_app(attr_threads, paged))
      run_feeding_attributes_test(attr_threads, { :count => 50000 })
    end
  end

  def get_app(attr_threads, paged)
    SearchApp.new.sd(selfdir + (paged ? "paged/" : "") + "test.sd").
      tune_searchnode({:feeding => {:concurrency => 0}}).
      visibility_delay(0.001).
      config(ConfigOverride.new("vespa.config.search.core.proton").
             add("indexing", ConfigValue.new("threads", attr_threads)))
  end

  def run_feeding_attributes_test(attr_threads, feed_params = {})
    #vespa.adminserver.logctl("searchnode:proton.server.storeonlyfeedview", "debug=on")
    feed_and_profile(FEEDING, attr_threads, feed_params.merge({ :template => put_template, :numthreads => 2 }))
    feed_and_profile(REFEEDING, attr_threads, feed_params.merge({ :template => put_template(reorder: true), :numthreads => 2 }))
    feed_and_profile(REMOVING, attr_threads, feed_params.merge({ :template => remove_template, :numthreads => 2 }))
  end

  def feed_and_profile(feed_stage, attr_threads, feed_params = {})
    profiler_start
    param_fillers = [parameter_filler(FEED_STAGE, feed_stage), parameter_filler(ATTRIBUTE_THREADS, attr_threads)]
    run_template_feeder(fillers: param_fillers, params: feed_params)
    profiler_report(get_label(feed_stage, attr_threads))
  end

  def clean_indexes_and_deploy_app(app)
    vespa.stop_base
    vespa.adminserver.clean_indexes
    deploy_app(app)
    start
  end

  def get_label(feed_stage, attr_threads)
    "#{FEED_STAGE}-#{feed_stage}.#{ATTRIBUTE_THREADS}-#{attr_threads}"
  end

  def teardown
    super
  end

end
