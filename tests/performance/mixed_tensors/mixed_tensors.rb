# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'environment'

class MixedTensorPerfTest < PerformanceTest

  FBENCH_RUNTIME = 30
  LABEL = "label"
  MIXED_BASIC = "mixed_basic"

  def initialize(*args)
    super(*args)
  end

  def test_mixed_tensor_operations
    set_description("Test performance of various mixed tensor operations")
    set_owner("geirst")
    @graphs = get_graphs
    deploy_and_prepare_data
    feed_docs(5000)
    run_fbench_helper
  end

  def deploy_and_prepare_data
    deploy_app(create_app)
    start
    @container = vespa.container.values.first
    compile_data_gen
    gen_query_file(100)
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      search_dir(selfdir + "search")
  end

  def compile_data_gen
    @data_gen = dirs.tmpdir + "data_gen"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_gen} #{selfdir}/data_gen.cpp")
  end

  def gen_query_file(num_queries)
    @query_file = dirs.tmpdir + "queries.txt"
    @container.execute("#{@data_gen} queries #{num_queries} > #{@query_file}")
  end

  def feed_docs(num_docs)
    @container.execute("#{@data_gen} puts #{num_docs} | vespa-feeder")
  end

  def run_fbench_helper
    fillers = [parameter_filler(LABEL, MIXED_BASIC)]
    profiler_start
    run_fbench2(@container,
                @query_file,
                {:runtime => FBENCH_RUNTIME, :clients => 1, :append_str => "&summary=minimal&timeout=10"},
                fillers)
    profiler_report(MIXED_BASIC)
  end

  def get_graphs
    [
      get_latency_graph(MIXED_BASIC, 5.0, 6.0)
    ]
  end

  def get_latency_graph(label, y_min, y_max)
    {
      :x => LABEL,
      :y => "latency",
      :title => "Historic average latency (#{label})",
      :filter => {LABEL => label},
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

end
