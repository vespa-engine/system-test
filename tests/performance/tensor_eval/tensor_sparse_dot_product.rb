# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance/tensor_eval/tensor_eval'

class TensorSparseDotProductTest < TensorEvalPerfTest

  def setup
    super
    set_owner("arnej")
  end

  def create_app
    SearchApp.new.sd(selfdir + "sparsedot.sd").
      search_dir(selfdir + "search").
      search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.TensorInQueryBuilderSearcher")))
  end

  def feed_docs(num_docs)
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{dirs.tmpdir}/dsd #{selfdir}/docs_sparse_dot.cpp")
    @container.execute("#{dirs.tmpdir}/dsd #{num_docs} | vespa-feeder")
  end

  def deploy_and_feed(num_docs_per_type)
    add_bundle(selfdir + "TensorInQueryBuilderSearcher.java")
    generate_tensor_files
    deploy_app(create_app)
    start
    @container = vespa.container.values.first
    generate_query_files
    feed_docs(num_docs_per_type)
    vespa.search["search"].first.trigger_flush
    vespa.search["search"].first.restart
  end

  def test_sparse_tensor_dot_product
    set_description("Test performance of sparse tensor dot product vs feature dot product calculation")
    @graphs = get_graphs_dot_product
    deploy_and_feed(100000)
    [[50,50], [10,50], [50,10], [250,50], [50,250]].each do |doc_entries, q_entries|
      w_query_f = "queries.dot_product_wset.#{q_entries}.txt"
      t_query_f = "queries.tensor.sparse_float.x.#{q_entries}.txt"
      run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT, doc_entries, w_query_f, q_entries, 8)
      run_fbench_helper(DOT_PRODUCT, SPARSE_TENSOR_DOT_PRODUCT, doc_entries, t_query_f, q_entries, 8)
      run_fbench_helper(DOT_PRODUCT, STRING_FEATURE_DP, doc_entries, w_query_f, q_entries, 8)
    end
  end

  def get_graphs_dot_product
    [
      get_latency_graphs_for_rank_profile(FEATURE_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(STRING_FEATURE_DP),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "50x50",   5.5,   7.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "50x10",   2.9,   3.2),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "10x50",   5.5,   7.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "50x250", 20.0,  22.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "250x50",  5.1,   5.8),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "50x50",  21.0,  25.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "50x10",   5.5,  10.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "10x50",  11.5,  15.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "50x250", 19.5,  23.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "250x50", 14.0,  18.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "50x50",   5.0,   7.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "50x10",   2.5,   3.5),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "10x50",   4.5,   7.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "50x250", 20.0,  40.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "250x50",  5.0,   6.0),
      get_latency_graph_for_all(PERF_LABEL)
    ]
  end

  def teardown
    super
  end

end
