# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/tensor_eval/tensor_eval'

class TensorUnstableDotProductPerfTest < TensorEvalPerfTest

  def setup
    set_owner('arnej')
  end

  def test_tensor_unstable_dot_product
    set_description('Test tensor dot product with unstable cell types')
    deploy_app(SearchApp.new.sd(selfdir + 'unstable.sd').search_dir(selfdir + 'unstable_search'))
    start
    @container = (vespa.qrserver['0'] or vespa.container.values.first)
    unstable_feed
    unstable_query
    @graphs = get_graphs_dot_product
    verify_same_results
  end

  def unstable_feed
    num_docs = 100000
    @container.execute("g++ -g -O2 -o #{dirs.tmpdir}/docs #{selfdir}/gen-unstable.cpp")
    @container.execute("#{dirs.tmpdir}/docs #{num_docs} #{dirs.tmpdir} | vespa-feed-perf")
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

  def get_graphs_dot_product
    [
      get_latency_graph_for_rank_profile('qry64doc64',     128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry32doc32',     128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry16doc16',     128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry8doc8',       128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry32doc8',      128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry32doc16',     128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry32doc8cast',  128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('qry32doc16cast', 128, 1.0, 200.0),
      get_latency_graph_for_rank_profile('default',        128, 1.0, 200.0)
    ]
  end

  def verify_same_results
    expect = 'documentid: id:unstable:unstable::57773 id: 57773 relevancy: 267030.0 sddocname: unstable source: search title: unstable 57773' +
          ' / documentid: id:unstable:unstable::36487 id: 36487 relevancy: 242505.0 sddocname: unstable source: search title: unstable 36487' +
          ' / documentid: id:unstable:unstable::44354 id: 44354 relevancy: 241427.0 sddocname: unstable source: search title: unstable 44354'
    results = []
    results.append(get_first_result('qry64doc64',     'qry64'))
    results.append(get_first_result('qry32doc32',     'qry32'))
    results.append(get_first_result('qry16doc16',     'qry16'))
    results.append(get_first_result('qry32doc16',     'qry32'))
    results.append(get_first_result('qry32doc16cast', 'qry32'))
    results.append(get_first_result('qry8doc8',       'qry8'))
    results.append(get_first_result('qry32doc8',      'qry32'))
    results.append(get_first_result('qry32doc8cast',  'qry32'))
    # puts "RESULTS :::"
    # results.each { |r| puts "RESULT: #{r}" }
    # puts "::: RESULTS"
    results.each { |r| assert_equal(expect, r) }
  end

  def get_first_result(rank_profile, qf)
    query_file = dirs.tmpdir + 'qf.' + qf
    line = File.open(query_file) { |f| f.readline }
    q = "#{line.chomp}&ranking=#{rank_profile}&timeout=10&hits=3&format=json"
    #puts "run query: #{q}"
    res = search(q)
    res.to_s.chomp.gsub("\n", ' / ')
  end

  def teardown
    stop
  end

end
