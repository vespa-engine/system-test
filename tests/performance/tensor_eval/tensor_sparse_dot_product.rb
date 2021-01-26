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
    #@container = (vespa.qrserver["0"] or vespa.container.values.first)
    @container = vespa.container.values.first
    generate_query_files
    feed_docs(num_docs_per_type)
  end

  def test_tensor_evaluation
    set_description("Test performance of sparse tensor dot product vs feature dot product calculation")
    @graphs = get_graphs_dot_product
    deploy_and_feed(100000)
    [10,250].each do |q_entries|
      [10,250].each do |doc_entries|
        run_fbench_helper(DOT_PRODUCT, FEATURE_DOT_PRODUCT,       doc_entries, "queries.dot_product_wset.#{q_entries}.txt",      q_entries)
        run_fbench_helper(DOT_PRODUCT, SPARSE_TENSOR_DOT_PRODUCT, doc_entries, "queries.tensor.sparse_float.x.#{q_entries}.txt", q_entries)
      end
    end
  end

  def get_graphs_dot_product
    [
      get_latency_graphs_for_rank_profile(FEATURE_DOT_PRODUCT),
      get_latency_graphs_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "10/10",   1.0, 300.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "10/250",  1.0, 300.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "250/10",  1.0, 300.0),
      get_latency_graph_for_rank_profile(FEATURE_DOT_PRODUCT,         "250/250", 1.0, 300.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "10/10",   1.0, 300.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "10/250",  1.0, 300.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "250/10",  1.0, 300.0),
      get_latency_graph_for_rank_profile(SPARSE_TENSOR_DOT_PRODUCT,   "250/250", 1.0, 300.0),
      {
        :x => RANK_PROFILE,
        :y => "latency",
        :title => "Historic latency for rank profiles with various number of entries in query and document",
        :historic => true
      }
    ]
  end

  def teardown
    super
  end

end
