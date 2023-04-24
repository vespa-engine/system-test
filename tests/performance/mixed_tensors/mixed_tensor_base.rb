# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'environment'

class MixedTensorPerfTestBase < PerformanceTest

  GRAPH_NAME = 'graph_name'
  FEED_TYPE = 'feed_type'
  LABEL_TYPE = 'label_type'
  PUTS = 'puts'
  UPDATES_ASSIGN = 'updates_assign'
  UPDATES_ADD = 'updates_add'
  UPDATES_REMOVE = 'updates_remove'
  STRING = 'string'

  def initialize(*args)
    super(*args)
  end

  def deploy_and_compile(sd_dir, sd_base_dir = nil)
    deploy_app(create_app(sd_dir, sd_base_dir))
    start
    @container = vespa.container.values.first
    compile_data_gen
  end

  def create_app(sd_dir, sd_base_dir)
    app = SearchApp.new.sd(selfdir + "#{sd_dir}/test.sd")
    app.sd(selfdir + "#{sd_base_dir}/base.sd") if sd_base_dir
    app.tune_searchnode( { :summary => { :store => { :logstore => { :chunk => { :compression => { :level => 3 } } } } } } )
    return app
  end

  def compile_data_gen
    tmp_bin_dir = @container.create_tmp_bin_dir
    @data_gen = "#{tmp_bin_dir}/data_gen"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_gen} #{selfdir}/data_gen.cpp")
  end

  def feed_and_profile_cases(data_gen_params_prefix)
    feed_and_profile("#{data_gen_params_prefix} puts", PUTS, STRING)
    feed_and_profile("#{data_gen_params_prefix} updates assign", UPDATES_ASSIGN, STRING)
    feed_and_profile("#{data_gen_params_prefix} updates add", UPDATES_ADD, STRING)
    feed_and_profile("#{data_gen_params_prefix} updates remove", UPDATES_REMOVE, STRING)
  end

  def warmup_feed(data_gen_params)
    command = "#{@data_gen} #{data_gen_params} puts"
    run_stream_feeder(command, [ parameter_filler(GRAPH_NAME, "warmup") ],
                      { :maxpending => 20, :numthreads => 2 })
  end

  def feed_and_profile(data_gen_params, feed_type, label_type)
    command = "#{@data_gen} #{data_gen_params}"
    profiler_start
    graph_name = "#{feed_type}.#{label_type}"
    run_stream_feeder(command, [
      parameter_filler(GRAPH_NAME, graph_name),
      parameter_filler(FEED_TYPE, feed_type),
      parameter_filler(LABEL_TYPE, label_type)
    ], { :maxpending => 0, :numthreads => 2, :timeout => 1800.0 })
    profiler_report(graph_name)
  end

end
