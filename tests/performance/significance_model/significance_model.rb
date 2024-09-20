# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'

class SignificanceModelPerfTest < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def test_weak_and_bm25
    set_description("Test performance of weakAnd + bm25 when using a significance model based on english wikipedia")
    # The dataset used in this test is a simplified version of the dataset used in ../ecommerce_hybrid_search perf tests.
    # It only contains the fields relevant for weakAnd search, without the metadata fields and vector field.
    # It was generated using ../ecommerce_hybrid_search/dataprep/generate_feed_query.py:
    #
    # python3 generate_feed_query.py --basefile_path output-data/ecommerce-1M.parquet --mode all --num_samples 1000000 --num_queries 10000 --weak_and_only
    #
    # Note: The queries are lowercased to bypass current limitations of a significance model.
    # TODO: Don't use lowercased queries when limitations are fixed.
    #
    deploy_app(get_app)
    @container = vespa.container.values.first
    start

    feed_file("feed-1M.json.zst")
    benchmark_queries("queries-lower-10k.json", "warmup", 8, true)
    benchmark_queries("queries-lower-model-10k.json", "warmup", 8, true)
    for clients in [1, 2, 4, 8, 16, 32, 64] do
      benchmark_queries("queries-lower-10k.json", "no_model", clients)
      benchmark_queries("queries-lower-model-10k.json", "use_model", clients)
    end
  end

  def get_app
    model_url = "https://data.vespa-cloud.com/tests/performance/significance_model/enwiki-20240801.json.zst"
    SearchApp.new.
      sd(selfdir + 'product.sd').
      search_dir(selfdir + "search").
      container(Container.new('default').
                search(Searching.new.significance(Significance.new.model_url(model_url))).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing_cluster('default').indexing_chain('indexing')
  end

  def feed_file(feed_file)
    node_file = download_file(feed_file, vespa.adminserver)
    run_feeder(node_file, [], {:client => :vespa_feed_client,
                               :compression => "none",
                               :localfile => true,
                               :silent => true,
                               :disable_tls => false})
  end

  def download_file(file_name, vespa_node)
    download_file_from_s3(file_name, vespa_node, "significance_model")
  end

  def benchmark_queries(query_file, type, clients, warmup = false, runtime = 20)
    node_file = download_file(query_file, @container)
    label = "#{type}_#{clients}"
    result_file = dirs.tmpdir + "result_#{label}.txt"
    fillers = [parameter_filler("label", label),
               parameter_filler("type", type),
               parameter_filler("clients", clients)]
    profiler_start if not warmup
    run_fbench2(@container,
                node_file,
                {:clients => clients,
                 :use_post => true,
                 :runtime => runtime,
                 :result_file => result_file},
                fillers)
    profiler_report(label) if not warmup
    @container.execute("head -12 #{result_file}")
  end

  def teardown
    super
  end

end
