# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'

class FeedingAndRemovingBase < PerformanceTest

  FEED_STAGE = "feed_stage"
  VISIBILITY_DELAY = "visibility_delay"
  INDEX_THREADS = "index_threads"
  # NOTE: These labels should ideally not have '1M' in their names.
  # To avoid losing previous benchmark data we keep them like this for now.
  FEEDING_DOCS = "feeding_1M_docs"
  REFEEDING_DOCS = "refeeding_1M_docs"
  REMOVING_DOCS = "removing_1M_docs"
  DELAY_0_SEC = "0_msec_delay"
  INDEX_THREADS_1 = "1_index_thread"
  INDEX_THREADS_2 = "2_index_threads"
  INDEX_THREADS_4 = "4_index_threads"
  INDEX_THREADS_8 = "8_index_threads"

  def initialize(*args)
    super(*args)
  end

  def create_app(visibility_delay = 0, index_threads = 1)
    sd_file = selfdir + "test.sd"
    app = SearchApp.new.sd(sd_file).
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(Searching.new).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer").
      redundancy(1).ready_copies(1).threads_per_search(4).
      disable_flush_tuning.
      tune_searchnode({:feeding => {:concurrency => 0}}).
      config(ConfigOverride.new("vespa.config.search.core.proton").
               add("indexing", ConfigValue.new("threads", index_threads)))
    if visibility_delay > 0
      app.config(ConfigOverride.new("vespa.config.search.core.proton").
                 add("maxvisibilitydelay", 30.0).
                 add("indexing", ConfigValue.new("semiunboundtasklimit", 2000))).
          visibility_delay(visibility_delay)
    end
    return app
  end

  def doc_template
    '{ "put": "id:test:test::$seq()", "fields": { "text1": "$words(100)", "text2": "$words(100)", "text3": "$words(100)", "text4": "$words(100)" } }'
  end

  def remove_template
    '{ "remove": "id:test:test::$seq()" }'
  end

  def run_feed_refeed_remove_test(visibility_delay, index_threads = INDEX_THREADS_1, doc_limit=200000)
    #vespa.adminserver.logctl("searchnode:proton.server.storeonlyfeedview", "debug=on")
    feed_params = { :count => doc_limit }
    feed_and_profile(FEEDING_DOCS, visibility_delay, index_threads, doc_limit, feed_params.merge({:template => doc_template}))
    feed_and_profile(REFEEDING_DOCS, visibility_delay, index_threads, doc_limit, feed_params.merge({:template => doc_template}))
    feed_and_profile(REMOVING_DOCS, visibility_delay, index_threads, 0, feed_params.merge({:numthreads => 1, :template => remove_template}))
  end

  def feed_and_profile(feed_stage, visibility_delay, index_threads, doc_count, feed_params = {})
    profiler_start
    system_sampler = create_system_sampler
    fillers = create_parameter_fillers(feed_stage, visibility_delay, index_threads) + [system_metric_filler(system_sampler)]
    run_template_feeder(fillers: fillers, params: feed_params)
    profiler_report(feed_stage + "_" + visibility_delay.to_s + "_" + index_threads.to_s)
    write_metrics(feed_stage, visibility_delay, index_threads)
    wait_for_hitcount("sddocname:test", doc_count, 60, 0, {:cluster => "combinedcontainer"})
  end

  def write_metrics(feed_stage, visibility_delay, index_threads)
    node = vespa.search["search"].first
    metrics = node.get_total_metrics
    proton_index_memoryusage_last = metrics.get("content.proton.documentdb.index.memory_usage.allocated_bytes", {"documenttype" => "test"})['last'].to_f/(1024*1024)
    write_report(create_parameter_fillers(feed_stage, visibility_delay, index_threads) +
                 [metric_filler("proton_index_memoryusage_last", proton_index_memoryusage_last)])
  end

  def create_parameter_fillers(feed_stage, visibility_delay, index_threads)
    [parameter_filler(FEED_STAGE, feed_stage), parameter_filler(VISIBILITY_DELAY, visibility_delay), parameter_filler(INDEX_THREADS, index_threads)]
  end

  def create_system_sampler
    system_sampler = Perf::System::new(vespa.search["search"].first)
    system_sampler.start
    return system_sampler
  end

  def system_metric_filler(system_sampler)
    # This proc will end the system sampling (cpuutil) and fill the metrics to the given result model
    Proc.new do |result|
      system_sampler.end
      system_sampler.fill.call(result)
    end
  end

  def clean_indexes_and_deploy_app(app)
    vespa.stop_base
    vespa.adminserver.clean_indexes
    deploy_app(app)
    start
  end

end
