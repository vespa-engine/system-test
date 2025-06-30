# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'uri'

class FuzzyMatchingPerfTest < PerformanceTest

  LABEL = "label"
  ALGORITHM = "algorithm"
  MATCH_PERCENT = "match_percent"
  PREFIX_LENGTH = "prefix_length"
  FILTER_PERCENT = "filter_percent"
  FBENCH_TIME = 10

  def setup
    super
    set_owner("hmusum")

    # The documents and queries used in this performance test are
    # generated from a dictionary dump obtained from the
    # "Wikipedia simple english from December 2022" data set:
    # https://huggingface.co/datasets/Cohere/wikipedia-22-12-simple-embeddings
    #
    # Run the ../nearest_neighbor/nearest_neighbor_wiki_multivec.rb performance test
    # and use the vespa-index-inspect dumpwords tool:
    # https://docs.vespa.ai/en/reference/vespa-cmdline-tools.html#vespa-index-inspect
    #
    # vespa-index-inspect dumpwords [--indexdir indexDir] --field text > dict.dump
    #
    # All non [a-z] words are filtered away:
    # grep "^[a-z]*\t" dict.dump > dict.us.dump
    #
    # Create 2M documents where the document frequency of the words in the dictionary
    # are preserved via linear scaling:
    # python3 create_docs.py dict.us.dump -d 187340 -c 2000000 > docs.2M.json
    #
    # The dictionary is analyzed to find words that when used as fuzzy query terms
    # return a particular amount of the corpus (0.01%, 0.1% and 1%):
    #
    # python3 analyze_dictionary.py dict.us.dump -d 187340 -w 1000 -f 0.0001 > dict.us.analyze.0001
    # python3 analyze_dictionary.py dict.us.dump -d 187340 -w 1000 -f 0.001 > dict.us.analyze.001
    # python3 analyze_dictionary.py dict.us.dump -d 187340 -w 1000 -f 0.01 > dict.us.analyze.01
    #
    # These analyse files are used to generate the query files:
    # ./create_queries.sh
    #
    # The same scripts can be used to generate documents and queries for a difference
    # dictionary dump.
    #

    @data_path = "fuzzy_matching/wiki"
    @docs = "docs.2M.json.zst"
  end

  def test_fuzzy_matching_wiki
    set_description("Test fuzzy matching performance of various algorithms using a dictionary dump from a wiki dataset")
    deploy_app(create_app)
    @container = vespa.container.values.first
    start
    node_file = download_file(@docs, vespa.adminserver)
    feed_file(node_file)
    run_query_benchmarks
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      threads_per_search(1).
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(Searching.new).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer")
  end

  def run_query_benchmarks
    algorithms = ["brute_force", "dfa_explicit", "dfa_table"]
    match_percents = [0.1, 1, 10, 50]
    for m in match_percents do
      for a in algorithms do
        query_and_benchmark(a, m, 0, "none")
        query_and_benchmark(a, m, 1, "none")
      end
    end
    filter_percents = [0.1, 1, 10, 50, 90]
    for f in filter_percents do
      for a in algorithms do
        query_and_benchmark(a, 10, 0, f)
      end
    end
  end

  def query_and_benchmark(algorithm, match_percent, prefix_length, filter_percent)
    label = "#{algorithm}_m#{match_percent}_p#{prefix_length}_f#{filter_percent}"
    query_file = fetch_query_file_to_container(match_percent, prefix_length, filter_percent)
    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(LABEL, label),
               parameter_filler(ALGORITHM, algorithm),
               parameter_filler(MATCH_PERCENT, match_percent),
               parameter_filler(PREFIX_LENGTH, prefix_length),
               parameter_filler(FILTER_PERCENT, filter_percent)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => 1,
                 :append_str => "&timeout=10s&hits=0&ranking.properties.vespa.matching.fuzzy.algorithm=#{algorithm}",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -12 #{result_file}")
  end

  def fetch_query_file_to_container(match_percent, prefix_length, filter_percent)
    file = "queries_m#{match_percent}_p#{prefix_length}_f#{filter_percent}.txt"
    download_file(file, @container)
  end

  def download_file(file_name, vespa_node)
    download_file_from_s3(file_name, vespa_node, @data_path)
  end

  def feed_file(feed_file)
    run_stream_feeder("zstdcat #{feed_file}", [],
                      {:client => :vespa_feed_client,
                       :compression => 'none',
                       :localfile => true,
                       :silent => true,
                       :disable_tls => false})
  end

  def teardown
    super
  end

end
