# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'

class FeedingMultipleDocTypesTest < PerformanceTest

  def initialize(*args)
    super(*args)
    @num_docs = 1000000
    @base_sd_file = selfdir + "test.sd"
  end

  def setup
    super
    set_owner("geirst")
  end

  def put_template
    '{ "put": "id:test:test::$seq()", "fields": { "number": 1000, "body": "$words(360)" } }'
  end

  def update_template
    '{ "update": "id:test:test::$seq()", "fields": { "number": { "assign": 2000 } } }'
  end

  def test_feeding_multiple_doc_types
    set_description("Test put and update feed performance with 1, 16 and 256 configured doc types")

    deploy_app(create_app([@base_sd_file]))
    start
    vespa_destination_start

    run_feeding_test("1_type")

    clean_indexes_and_deploy_app(create_app([@base_sd_file] + create_sd_files(15)))
    run_feeding_test("16_types")

    clean_indexes_and_deploy_app(create_app([@base_sd_file] + create_sd_files(255)))
    run_feeding_test("256_types")
  end

  def run_feeding_test(doc_types)
    feed_and_profile(put_template, "feeding_docs", doc_types)
    wait_for_hitcount("sddocname:test", @num_docs, 60, 0, {:cluster => "combinedcontainer"})
    assert_hitcount("sddocname:test", @num_docs, 0, {:cluster => "combinedcontainer"})
    feed_and_profile(update_template, "feeding_updates", doc_types)
    wait_for_hitcount("number:2000", @num_docs, 60, 0, {:cluster => "combinedcontainer"})
    assert_hitcount("number:2000", @num_docs, 0, {:cluster => "combinedcontainer"})
  end

  def feed_and_profile(template, feed_stage, doc_types, feed_params_in = {})
    feed_params = { :template => template, :count => @num_docs, :numthreads => 3 }
    feed_params = feed_params.merge(feed_params_in)
    feed(feed_params.merge(:route => '"combinedcontainer/chain.indexing null/default"'))
    profiler_start
    system_sampler = Perf::System::new(vespa.search["search"].first)
    system_sampler.start
    fillers = [parameter_filler("feed_stage", feed_stage), parameter_filler("doc_types", doc_types), system_metric_filler(system_sampler)]
    run_template_feeder(fillers: fillers, params: feed_params)
    profiler_report(feed_stage + "_" + doc_types)
  end

  def system_metric_filler(system_sampler)
    # This proc will end the system sampling (cpuutil) and fill the metrics to the given result model
    Proc.new do |result|
      system_sampler.end
      system_sampler.fill.call(result)
    end
  end

  def create_app(sd_files)
    app = SearchApp.new.
            visibility_delay(0.002).
            disable_flush_tuning.
            container(Container.new("combinedcontainer").
                      jvmoptions('-Xms16g -Xmx16g').
                      search(Searching.new).
                      docproc(DocumentProcessing.new).
                      documentapi(ContainerDocumentApi.new)).
            indexing("combinedcontainer").
            config(ConfigOverride.new("vespa.config.content.stor-filestor").
                   add("num_threads", "16").
                   add("num_response_threads", "2"))
    sd_files.each do |sd_file|
      app.sd(sd_file)
    end
    return app
  end

  def create_sd_files(num_files)
    retval = []
    for i in 1..num_files do
      sd_name = "test#{i}"
      dest_sd_file = "#{dirs.tmpdir}#{sd_name}.sd"
      sd_content = "search #{sd_name} { document #{sd_name} { field f1 type string { indexing: index | summary } } }"
      system("echo \"#{sd_content}\" > #{dest_sd_file}")
      retval.push(dest_sd_file)
    end
    return retval
  end

  def clean_indexes_and_deploy_app(app)
    vespa.stop_base
    vespa.adminserver.clean_indexes
    deploy_app(app)
    start
  end

  def teardown
    super
  end

end
