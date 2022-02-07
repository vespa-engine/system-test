# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'

class FastAccessAttributesPerfTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def put_template
    '{ "put":"id:test:test::$seq()", "fields": { "normal_access": 1000, "fast_access": 1000, "body": "$words(360)" } }'
  end

  def update_template(field)
    '{ "update":"id:test:test::$seq()", "fields": { "' + field + '": { "assign": 2000 } } }'
  end

  def conditional_update_template(field)
    '{ "update":"id:test:test::$seq()", "condition": "test.' + field + ' == 2000", "fields": { "' + field + '": { "assign": 3000 } } }'
  end

  def test_partial_update_feed
    set_description("Test partial update feed performance for normal and fast access attributes")
    sd_file = selfdir + "test.sd"
    @num_docs = 1000000
    # With num_parts=2, redundancy=2 and ready_copies=1 we get ~50% non-ready (non-searchable)
    # documents on each of the 2 search nodes. The normal_access attribute will not be loaded for these
    # non-ready documents while the fast_access attribute will. Updates to the normal_access attribute
    # will have worse feed performance as these documents must be fetched from disk for applying the updates.
    app = SearchApp.new.enable_document_api.sd(sd_file).
      container(Container.new("combinedcontainer").
                    jvmoptions('-Xms8g -Xmx8g').
                    search(Searching.new).
                    docproc(DocumentProcessing.new).
                    documentapi(ContainerDocumentApi.new)).
          indexing("combinedcontainer").
      num_parts(2).redundancy(2).ready_copies(1).
      visibility_delay(0.002).
      disable_flush_tuning.
      tune_searchnode({ :summary => {:io => {:read => :directio}},
                        :feeding => {:concurrency => 1.0 }})
    deploy_app(app)
    #vespa.adminserver.logctl("searchnode:search.filechunk", "debug=on")
    #vespa.adminserver.logctl("searchnode2:search.filechunk", "debug=on")
    start
    feed({:template => put_template, :count => @num_docs})
    wait_for_hits("sddocname:test", @num_docs)
    assert_hitcount("normal_access:1000", @num_docs)
    assert_hitcount("fast_access:1000", @num_docs)

    feed_and_profile(update_template("normal_access"), "feeding_normal_access")
    wait_for_hits("normal_access:2000", @num_docs)
    assert_hitcount("normal_access:1000", 0)
    feed_and_profile(update_template("fast_access"), "feeding_fast_access")
    wait_for_hits("fast_access:2000", @num_docs)
    assert_hitcount("fast_access:1000", 0)

    feed_and_profile(conditional_update_template("normal_access"), "feeding_conditional_normal_access")
    wait_for_hits("normal_access:3000", @num_docs)
    assert_hitcount("normal_access:2000", 0)

    feed_and_profile(conditional_update_template("fast_access"), "feeding_conditional_fast_access")
    wait_for_hits("fast_access:3000", @num_docs)
    assert_hitcount("fast_access:2000", 0)

    feed_and_profile(update_template("fast_access"), "feeding_fast_access_direct", {:route => '"search-direct"'})
    wait_for_hits("fast_access:2000", @num_docs)
    assert_hitcount("fast_access:3000", 0)
  end

  def feed_and_profile(feed_template, feed_stage, params={})
    params = params.merge({:template => feed_template, :count => @num_docs})
    puts "feed_params = " + params.to_s
    profiler_start
    run_template_feeder(fillers: [parameter_filler("feed_stage", feed_stage)], params: params)
    profiler_report(feed_stage)
  end

  def wait_for_hits(query, num_docs)
    wait_for_hitcount(query, num_docs, 60, 0, {:cluster => "combinedcontainer"})
  end

  def teardown
    super
  end

end
