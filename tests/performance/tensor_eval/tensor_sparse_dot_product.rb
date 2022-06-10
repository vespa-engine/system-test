# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
      container(Container.new.
                  search(Searching.new.
                           chain(Chain.new("default", "vespa").add(Searcher.new("com.yahoo.test.TensorInQueryBuilderSearcher")))).
                  docproc(DocumentProcessing.new).
                  jvmoptions("-Xms16g -Xmx16g"))
  end

  def feed_docs(num_docs)
    tmp_bin_dir = @container.create_tmp_bin_dir
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{tmp_bin_dir}/dsd #{selfdir}/docs_sparse_dot.cpp")
    @container.execute("#{tmp_bin_dir}/dsd #{num_docs} | vespa-feeder")
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
    wait_for_hitcount("sddocname:sparsedot", num_docs_per_type*3, 60) # Fed with 10, 50, and 250
  end

  def test_sparse_tensor_dot_product
    set_description("Test performance of sparse tensor dot product vs feature dot product calculation")
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

  def teardown
    super
  end

end
