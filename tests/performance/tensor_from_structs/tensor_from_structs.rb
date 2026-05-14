# coding: utf-8
# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'performance/fbench'
require 'app_generator/search_app'
require 'environment'

class TensorFromStructsPerfTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner('arnej')
    @perf_recording = 'some'
  end

  def create_app
    SearchApp.new.sd(selfdir + 'test.sd').disable_flush_tuning.
      container(Container.new.search(Searching.new).
                  jvmoptions('-Xms8g -Xmx8g'))
  end

  def test_make_tensor_from_struct
    set_description('Test query performance while making tensors from structs')
    deploy_app(create_app)
    start
    @container = vespa.container.values.first
    compile_data_generator
    @num_docs = 100
    feed_docs(@num_docs)
    run_queries('default')
    run_queries('combine2keys')
  end

  def feeder_numthreads
      3
  end

  def compile_data_generator
    tmp_bin_dir = vespa.adminserver.create_tmp_bin_dir
    @data_generator = "#{tmp_bin_dir}/data_generator"
    vespa.adminserver.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -Wall -g -O3 -o #{@data_generator} #{selfdir}/data_generator.cpp")
  end

  def feed_docs(num_docs)
    feed_stream("#{@data_generator} put #{num_docs}")
  end

  def run_queries(rank_profile)
    @container.copy(selfdir + 'qf.1', dirs.tmpdir)
    fillers = [ parameter_filler('ranking', rank_profile) ]
    profiler_start
    run_fbench2(@container,
                dirs.tmpdir + 'qf.1',
                {:runtime => 30, :clients => 30,
                 :append_str => "&ranking=#{rank_profile}&timeout=10"},
                fillers)
    profiler_report(rank_profile)
  end

end
