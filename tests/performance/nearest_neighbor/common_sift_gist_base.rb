# Copyright Vespa.ai. All rights reserved.

require 'app_generator/search_app'
require 'performance/fbench'
require 'performance/nearest_neighbor/common_ann_base'

class CommonSiftGistBase < CommonAnnBaseTest

  FBENCH_TIME = 10

  def create_app(test_folder, concurrency = nil, threads_per_search = 1)
    add_bundle(selfdir + "NearestNeighborRecallSearcher.java")
    searching = Searching.new
    searching.chain(Chain.new("default", "vespa").add(Searcher.new("ai.vespa.test.NearestNeighborRecallSearcher")))
    app = SearchApp.new.sd(selfdir + test_folder + "/test.sd").
      search_dir(selfdir + test_folder + "/search").
      threads_per_search(threads_per_search).
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(searching).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer")
    if (concurrency != nil)
      app.tune_searchnode({:feeding => {:concurrency => concurrency}})
    end
    return app
  end

  def get_type_string(filter_percent, threads_per_search)
    if threads_per_search > 0
      return "query_threads"
    elsif filter_percent == 0
      return "query"
    else
      return "query_filter"
    end
  end

  def get_rank_profile(threads_per_search)
    (threads_per_search > 0) ? "threads-#{threads_per_search}" : "default"
  end

  def query_and_benchmark(algorithm, target_hits, explore_hits, params = {})
    filter_percent = params[:filter_percent] || 0
    approximate_threshold = params[:approximate_threshold] || 0.05
    filter_first_threshold = params[:filter_first_threshold] || 0.0
    filter_first_exploration = params[:filter_first_exploration] || 0.3
    slack = params[:slack] || 0.0
    clients = params[:clients] || 1
    threads_per_search = params[:threads_per_search] || 0

    approximate = algorithm == HNSW ? "true" : "false"
    query_file = fetch_query_file_to_container(approximate, target_hits, explore_hits, filter_percent)
    label = params[:label] || "#{algorithm}-th#{target_hits}-eh#{explore_hits}-f#{filter_percent}-at#{approximate_threshold}-fft#{filter_first_threshold}-ffe#{filter_first_exploration}-sl#{slack}-n#{clients}-t#{threads_per_search}"
    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(TYPE, get_type_string(filter_percent, threads_per_search)),
               parameter_filler(LABEL, label),
               parameter_filler(ALGORITHM, algorithm),
               parameter_filler(TARGET_HITS, target_hits),
               parameter_filler(EXPLORE_HITS, explore_hits),
               parameter_filler(SLACK, slack),
               parameter_filler(FILTER_PERCENT, filter_percent),
               parameter_filler(APPROXIMATE_THRESHOLD, approximate_threshold),
               parameter_filler(FILTER_FIRST_THRESHOLD, filter_first_threshold),
               parameter_filler(FILTER_FIRST_EXPLORATION, filter_first_exploration),
               parameter_filler(CLIENTS, clients),
               parameter_filler(THREADS_PER_SEARCH, threads_per_search)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => clients,
                 :append_str => "&summary=minimal&hits=#{target_hits}&ranking=#{get_rank_profile(threads_per_search)}&ranking.matching.approximateThreshold=#{approximate_threshold}&ranking.matching.filterFirstThreshold=#{filter_first_threshold}&ranking.matching.filterFirstExploration=#{filter_first_exploration}&ranking.matching.explorationSlack=#{slack}",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -10 #{result_file}")
  end

  # The values for explore_hits are calculated based on what is used in
  # https://github.com/erikbern/ann-benchmarks/blob/master/algos.yaml.
  # For hnswlib the following values are used for the 'ef' parameter
  # (the size of the dynamic list for the nearest neighbors (used during the search)):
  # [10, 20, 40, 80, 120, 200, 400, 600, 800]
  #
  # In Vespa the same value is (target_hits + explore_hits)

  def run_target_hits_10_tests
    [0, 10, 30, 70, 110, 190, 390, 590, 790].each do |explore_hits|
      query_and_benchmark(HNSW, 10, explore_hits)
      calc_recall_for_queries(10, explore_hits)
    end

    [0.00, 0.05, 0.10, 0.15, 0.2, 0.3, 0.4, 0.5].each do |slack|
      query_and_benchmark(HNSW, 10, 0, {:slack => slack})
      calc_recall_for_queries(10, 0, {:slack => slack})
    end
  end

  def run_target_hits_100_tests
    [0, 20, 100, 300, 500, 700].each do |explore_hits|
      query_and_benchmark(HNSW, 100, explore_hits)
      calc_recall_for_queries(100, explore_hits)
    end

    [0.00, 0.05, 0.10, 0.15, 0.2, 0.3, 0.4, 0.5].each do |slack|
      query_and_benchmark(HNSW, 100, 0, {:slack => slack})
      calc_recall_for_queries(100, 0, {:slack => slack})
    end

    # Now with filtering and filter first
    [0.00, 0.05, 0.10, 0.15, 0.2, 0.3, 0.4, 0.5].each do |slack|
      query_and_benchmark(HNSW, 100, 0, {:filter_percent => 95, :approximate_threshold => 0.00, :filter_first_threshold => 0.4, :filter_first_exploration => 0.3, :slack => slack})
      calc_recall_for_queries(100, 0, {:filter_percent => 95, :approximate_threshold => 0.00, :filter_first_threshold => 0.4, :filter_first_exploration => 0.3, :slack => slack})
    end
  end

  def run_removal_test(file, label, documents_to_benchmark, documents_in_total)
    puts "About to feed #{documents_to_benchmark} of #{documents_in_total}"
    feed_and_benchmark_range(file, "#{label}-0-#{documents_to_benchmark}", 0, documents_to_benchmark)
    assert_hitcount("query=sddocname:test", documents_to_benchmark)

    puts "Benchmarking before deletion"
    query_and_benchmark(HNSW, 100, 0)
    calc_recall_for_queries(100, 0)

    puts "Feeding the remaining documents..."
    feed_and_benchmark_range(file, "#{label}-#{documents_to_benchmark}-#{documents_in_total}", documents_to_benchmark, documents_in_total)

    puts "...and removing them again"
    vespa.document_api_v1.http_delete("/document/v1/test/test/docid?cluster=search&selection=#{CGI.escape("test.id>=#{documents_to_benchmark} and test.id<#{documents_in_total}")}")
    assert_hitcount("query=sddocname:test", documents_to_benchmark)

    puts "Benchmarking after deletion"
    query_and_benchmark(HNSW, 100, 0)
    calc_recall_for_queries(100, 0)
  end

  def fetch_query_file_to_container(approximate, target_hits, explore_hits, filter_percent)
    filter_str = (filter_percent == 0) ? "" : ".f-#{filter_percent}"
    remote_file = @data_path + "queries.vec_m16.ap-#{approximate}.th-#{target_hits}.eh-#{explore_hits}#{filter_str}.txt"
    proxy_file = nn_download_file(remote_file, @container)
    puts "Got on container: #{proxy_file}"
    return proxy_file
  end

end
