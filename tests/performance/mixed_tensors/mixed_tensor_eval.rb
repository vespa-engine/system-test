# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require_relative 'mixed_tensor_base'

class MixedTensorPerfTest < MixedTensorPerfTestBase

  FBENCH_RUNTIME = 30
  RANK_PROFILE = "rank_profile"
  SINGLE_MODEL = "single_model"
  MULTI_MODEL_EARLY_REDUCE = "multi_model_early_reduce"
  MULTI_MODEL_LATE_REDUCE = "multi_model_late_reduce"

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
    deploy_and_compile("vec_256")
    gen_query_files(100)
  end

  def gen_query_files(num_queries)
    @single_model_file = dirs.tmpdir + "single_model_queries.txt"
    @multi_model_file = dirs.tmpdir + "multi_model_queries.txt"
    @container.execute("#{@data_gen} -o #{num_queries} queries single > #{@single_model_file}")
    @container.execute("#{@data_gen} -o #{num_queries} queries multi > #{@multi_model_file}")
  end

  def feed_docs(num_docs)
    @container.execute("#{@data_gen} -o #{num_docs} -f all puts | vespa-feeder")
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
      get_latency_graph(SINGLE_MODEL, 4.0, 4.5),
      get_latency_graph(MULTI_MODEL_EARLY_REDUCE, 7.5, 8.5),
      get_latency_graph(MULTI_MODEL_LATE_REDUCE, 4.9, 5.6)
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
