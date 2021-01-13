# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'environment'

class MixedTensorPerfTestBase < PerformanceTest

  FEED_TYPE = "feed_type"
  LABEL_TYPE = "label_type"
  PUTS = "puts"
  UPDATES_ASSIGN = "updates_assign"
  UPDATES_ADD = "updates_add"
  NUMBER = "number"
  STRING = "string"

  def initialize(*args)
    super(*args)
  end

  def deploy_and_compile
    deploy_app(create_app)
    start
    @container = vespa.container.values.first
    compile_data_gen
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      search_dir(selfdir + "search")
  end

  def compile_data_gen
    @data_gen = dirs.tmpdir + "data_gen"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_gen} #{selfdir}/data_gen.cpp")
  end

  def feed_and_profile(data_gen_params, feed_type, label_type)
    command = "#{@data_gen} #{data_gen_params}"
    profiler_start
    run_stream_feeder(command, [parameter_filler(FEED_TYPE, feed_type), parameter_filler(LABEL_TYPE, label_type)], {})
    profiler_report("#{feed_type}")
  end

  def get_feed_throughput_graph(feed_type, label_type, y_min, y_max)
    {
      :x => FEED_TYPE,
      :y => "feeder.throughput",
      :title => "Throughput during feeding of '#{feed_type}' (#{LABEL_TYPE}=#{label_type}) to mixed tensor",
      :filter => { FEED_TYPE => feed_type, LABEL_TYPE => label_type },
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

end
