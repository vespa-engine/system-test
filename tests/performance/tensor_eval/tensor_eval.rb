# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/tensor_eval/utils/query_generator'
require 'performance/tensor_eval/utils/tensor_generator'
require 'pp'
require 'environment'

class TensorEvalPerfTest < PerformanceTest

  FBENCH_RUNTIME = 20
  EVAL_TYPE = "eval_type"
  RANK_PROFILE = "rank_profile"
  PERF_LABEL = "perf_label"
  WSET_ENTRIES = "wset_entries"
  DOT_PRODUCT = "dot_product"
  MATCH = "match"
  SPARSE_MULTIPLY = "sparse_multiply"
  MATRIX_PRODUCT = "matrix_product"
  FEATURE_DOT_PRODUCT = "feature_dot_product"
  FEATURE_DOT_PRODUCT_ARRAY = "feature_dot_product_array"
  SPARSE_TENSOR_DOT_PRODUCT = "sparse_tensor_dot_product"
  SPARSE_MULTIPLY_NO_OVERLAP = "sparse_multiply_no_overlap"
  SPARSE_MULTIPLY_PARTIAL_OVERLAP = "sparse_multiply_partial_overlap"
  TENSOR_MATCH_25X25 = "tensor_match_25x25"
  TENSOR_MATCH_50X50 = "tensor_match_50x50"
  TENSOR_MATCH_100X100 = "tensor_match_100x100"
  DENSE_TENSOR_DOT_PRODUCT = "dense_tensor_dot_product"
  DENSE_FLOAT_TENSOR_DOT_PRODUCT = "dense_float_tensor_dot_product"

  def initialize(*args)
    super(*args)
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      search_dir(selfdir + "search").
      search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.TensorInQueryBuilderSearcher"))).
      rank_expression_file(dirs.tmpdir + "sparse_tensor_25x25.json").
      rank_expression_file(dirs.tmpdir + "sparse_tensor_50x50.json").
      rank_expression_file(dirs.tmpdir + "sparse_tensor_100x100.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_10x10.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_25x25.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_50x50.json").
      rank_expression_file(dirs.tmpdir + "dense_matrix_100x100.json")
  end

  def deploy_and_feed(num_docs_per_type)
    add_bundle(selfdir + "TensorInQueryBuilderSearcher.java")
    generate_tensor_files
    deploy_app(create_app)
    start
    generate_query_files
    feed_docs(num_docs_per_type)
    @container = vespa.container.values.first
  end

  def generate_tensor_files
    puts "generate_tensor_files"
    TensorEvalTensorGenerator.write_tensor_files(dirs.tmpdir)
  end

  def generate_query_files()
    puts "generate_query_files()"
    TensorEvalQueryGenerator.write_query_files(dirs.tmpdir)
  end

  def feed_docs(num_docs)
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    tmp_bin_dir = container.create_tmp_bin_dir
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{tmp_bin_dir}/docs #{selfdir}/docs.cpp", { :stderr => true })
    container.execute("#{tmp_bin_dir}/docs #{num_docs} | vespa-feeder")
  end

  def run_fbench_helper(eval_type, rank_profile, doc_wset_entries, query_file, q_wset_entries = nil, clients=1)
    wset_entries="#{doc_wset_entries}"
    wset_entries="#{q_wset_entries}x#{doc_wset_entries}" if q_wset_entries

    puts "run_fbench_helper(#{eval_type}, #{rank_profile}, #{wset_entries}, #{query_file}, clients=#{clients})"
    query_file = fetch_query_file(query_file)
    perf_label = get_label(eval_type, rank_profile, wset_entries)
    fillers = [parameter_filler(EVAL_TYPE, eval_type),
               parameter_filler(RANK_PROFILE, rank_profile),
               parameter_filler(PERF_LABEL, perf_label),
               parameter_filler(WSET_ENTRIES, wset_entries)]
    mangled_rank_profile = rank_profile
    if rank_profile == DENSE_TENSOR_DOT_PRODUCT || rank_profile == DENSE_FLOAT_TENSOR_DOT_PRODUCT
      mangled_rank_profile = "#{rank_profile}_#{doc_wset_entries}"
    end
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_RUNTIME, :clients => clients,
                 :append_str => "&query=wset_entries:#{doc_wset_entries}&ranking=#{mangled_rank_profile}&summary=min_summary&timeout=10"},
                fillers)
    profiler_report(perf_label)
  end

  def fetch_query_file(query_file)
    query_file = dirs.tmpdir + query_file
    @container.copy(query_file, File.dirname(query_file))
    query_file
  end

  def get_label(eval_type, rank_profile, wset_entries)
    "#{EVAL_TYPE}-#{eval_type}.#{RANK_PROFILE}-#{rank_profile}.#{WSET_ENTRIES}-#{wset_entries}"
  end

end
