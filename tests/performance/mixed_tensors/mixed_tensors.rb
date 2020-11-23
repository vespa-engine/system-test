# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'
require 'environment'

class MixedTensorPerfTest < PerformanceTest

  FBENCH_RUNTIME = 30
  RANK_PROFILE = "rank_profile"
  SINGLE_MODEL = "single_model"
  MULTI_MODEL_EARLY_REDUCE = "multi_model_early_reduce"
  MULTI_MODEL_LATE_REDUCE = "multi_model_late_reduce"

  def initialize(*args)
    super(*args)
  end

  def test_mixed_tensor_operations
    set_description("Test performance of various mixed tensor operations")
    set_owner("geirst")
    @graphs = get_graphs
    deploy_and_prepare_data
    feed_docs(5000)
    run_fbench_helper(SINGLE_MODEL, @single_model_file)
    run_fbench_helper(MULTI_MODEL_EARLY_REDUCE, @multi_model_file)
    run_fbench_helper(MULTI_MODEL_LATE_REDUCE, @multi_model_file)
  end

  def deploy_and_prepare_data
    deploy_app(create_app)
    start
    @container = vespa.container.values.first
    compile_data_gen
    gen_query_files(100)
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      search_dir(selfdir + "search")
  end

  def compile_data_gen
    @data_gen = dirs.tmpdir + "data_gen"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@data_gen} #{selfdir}/data_gen.cpp")
  end

  def gen_query_files(num_queries)
    @single_model_file = dirs.tmpdir + "single_model_queries.txt"
    @multi_model_file = dirs.tmpdir + "multi_model_queries.txt"
    @container.execute("#{@data_gen} queries single #{num_queries} > #{@single_model_file}")
    @container.execute("#{@data_gen} queries multi #{num_queries} > #{@multi_model_file}")
  end

  def feed_docs(num_docs)
    @container.execute("#{@data_gen} puts #{num_docs} | vespa-feeder")
  end

  def run_fbench_helper(rank_profile, query_file)
    fillers = [parameter_filler(RANK_PROFILE, rank_profile)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_RUNTIME, :clients => 1, :append_str => "&summary=minimal&timeout=10&ranking.profile=#{rank_profile}"},
                fillers)
    profiler_report(rank_profile)
  end

  def get_graphs
    [
      get_latency_graph(SINGLE_MODEL, 5.0, 6.0),
      get_latency_graph(MULTI_MODEL_EARLY_REDUCE, 5.0, 12.0),
      get_latency_graph(MULTI_MODEL_LATE_REDUCE, 5.0, 12.0)
    ]
  end

  def get_latency_graph(rank_profile, y_min, y_max)
    {
      :x => RANK_PROFILE,
      :y => "latency",
      :title => "Historic average latency (#{rank_profile})",
      :filter => {RANK_PROFILE => rank_profile},
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

end
