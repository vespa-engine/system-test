# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/tensor_eval/tensor_eval'

class TensorUnstableDotProductPerfTest < TensorEvalPerfTest

  def setup
    set_owner('arnej')
  end

  def test_tensor_unstable_dot_product
    set_description('Test tensor dot product with unstable cell types')
    deploy_app(SearchApp.new.sd(selfdir + 'unstable.sd'))
    start
    @container = (vespa.qrserver['0'] or vespa.container.values.first)
    unstable_feed
    unstable_query
  end

  def unstable_feed
    num_docs = 100000
    tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -g -O2 -o #{tmp_bin_dir}/docs #{selfdir}/gen-unstable.cpp")
    @container.execute("#{tmp_bin_dir}/docs #{num_docs} #{dirs.tmpdir} | vespa-feed-perf")
  end

  def unstable_query
    run_fbench_helper('default')
    run_fbench_helper('qry64doc64',     'qry64')
    run_fbench_helper('qry32doc32',     'qry32')
    run_fbench_helper('qry16doc16',     'qry16')
    run_fbench_helper('qry32doc16',     'qry32')
    run_fbench_helper('qry32doc16cast', 'qry32')
    run_fbench_helper('qry8doc8',       'qry8')
    run_fbench_helper('qry32doc8',      'qry32')
    run_fbench_helper('qry32doc8cast',  'qry32')
  end

  def run_fbench_helper(rank_profile, qf = rank_profile)
    query_file = dirs.tmpdir + 'qf.' + qf
    puts "run_fbench_helper(#{rank_profile}, #{query_file})"
    fillers = [ parameter_filler(RANK_PROFILE, rank_profile),
                parameter_filler(WSET_ENTRIES, 128) ]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => 30, :clients => 1,
                 :append_str => "&ranking=#{rank_profile}&timeout=10"},
                fillers)
    profiler_report(rank_profile)
  end

  def teardown
    stop
  end

end
