# Copyright Vespa.ai. All rights reserved.
# Private reason: Depends on pub/ data

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

  def query_and_benchmark(algorithm, target_hits, explore_hits, filter_percent = 0, clients = 1, threads_per_search = 0)
    approximate = algorithm == HNSW ? "true" : "false"
    query_file = fetch_query_file_to_container(approximate, target_hits, explore_hits, filter_percent)
    label = "#{algorithm}-th#{target_hits}-eh#{explore_hits}-f#{filter_percent}-n#{clients}-t#{threads_per_search}"
    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(TYPE, get_type_string(filter_percent, threads_per_search)),
               parameter_filler(LABEL, label),
               parameter_filler(ALGORITHM, algorithm),
               parameter_filler(TARGET_HITS, target_hits),
               parameter_filler(EXPLORE_HITS, explore_hits),
               parameter_filler(FILTER_PERCENT, filter_percent),
               parameter_filler(CLIENTS, clients),
               parameter_filler(THREADS_PER_SEARCH, threads_per_search)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => clients,
                 :append_str => "&summary=minimal&hits=#{target_hits}&ranking=#{get_rank_profile(threads_per_search)}",
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
      query_and_benchmark(HNSW, 10, explore_hits, 0, 1)
      calc_recall_for_queries(10, explore_hits)
    end
  end

  def run_target_hits_100_tests
    [0, 20, 100, 300, 500, 700].each do |explore_hits|
      query_and_benchmark(HNSW, 100, explore_hits, 0, 1)
      calc_recall_for_queries(100, explore_hits)
    end
  end

  def fetch_query_file_to_container(approximate, target_hits, explore_hits, filter_percent)
    filter_str = (filter_percent == 0) ? "" : ".f-#{filter_percent}"
    remote_file = @data_path + "queries.vec_m16.ap-#{approximate}.th-#{target_hits}.eh-#{explore_hits}#{filter_str}.txt"
    proxy_file = nn_download_file(remote_file, @container)
    puts "Got on container: #{proxy_file}"
    return proxy_file
  end

end
