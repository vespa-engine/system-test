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
      threads_per_search(1).
      qrservers_jvmargs("-Xms16g -Xmx16g").
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
    clients = 8
    deploy_and_feed(100000)
    [[50,50], [10,50], [50,10], [250,50], [50,250]].each do |doc_entries, q_entries|
      w_query_f = "queries.dot_product_wset.#{q_entries}.txt"
      t_query_f = "queries.tensor.sparse_float.x.#{q_entries}.txt"
      run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT, doc_entries, w_query_f, q_entries, clients)
      run_fbench_helper(DOT_PRODUCT, SPARSE_TENSOR_DOT_PRODUCT, doc_entries, t_query_f, q_entries, clients)
      run_fbench_helper(DOT_PRODUCT, STRING_FEATURE_DP, doc_entries, w_query_f, q_entries, clients)
    end
  end

  def get_graphs_dot_product
    [
      get_latency_graphs_for_rank_profile(FEATURE_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(STRING_FEATURE_DP),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "50x50",  15.5,  17.5),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "50x10",   6.9,   7.1),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "10x50",  19.0,  20.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "50x250", 69.0,  71.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "250x50", 16.2,  16.6),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "50x50",  58.0,  61.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "50x10",  21.5,  23.5),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "10x50",  37.0,  39.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "50x250", 70.0,  81.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "250x50", 35.0,  37.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "50x50",  16.2,  16.6),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "50x10",   6.7,   7.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "10x50",  16.0,  20.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "50x250", 70.0,  81.0),
      get_latency_graph_for_rank_profile(STRING_FEATURE_DP,           "250x50", 16.0,  16.4),
      get_latency_graph_for_all(PERF_LABEL)
    ]
  end

  def teardown
    super
  end

end
