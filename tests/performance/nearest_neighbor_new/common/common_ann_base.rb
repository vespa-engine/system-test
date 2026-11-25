# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

# Base class for performance tests of nearest neighbor search, independent of the data set:
# deploying an application with NearestNeighborRecallSearcher, feeding (a feed file or the output of a command),
# benchmarking query files with fbench, and calculating the recall.
#
# A query case is described by a hash of values, e.g.,
#   {:target_hits => 100, :approximate_threshold => 0.0, :filter_first_threshold => 0.2, :filter => "positive", ...}
# The tests configure how the values are used with set_request_parameters (the request parameters appended to the queries),
# set_label_format (the label of the reports), and set_report_parameters (the parameters of the reports).
# The values must contain :target_hits, the number of hits compared when calculating the recall.
# The generated queries are the same for benchmarking and for calculating the recall: the recall is calculated for the
# first queries of the benchmarked query file, with NearestNeighborRecallSearcher running each query as it is and with
# approximate=false (the exact ground truth). The schema needs a document summary 'minimal' with the field 'id'.
#
# Files in nearest_neighbor_new/:
#   common/                                                  independent of the data set: this class and
#                                                            NearestNeighborRecallSearcher.java
#   case_<data set>_<test>.rb                                the tests (the files with test_ methods)
#   <data set>/                                              everything specific to the data set: a subclass for the
#                                                            data set and one per kind of test, the document and query
#                                                            generators, the data, and the schemas, e.g., cohere/
class CommonAnnBase < PerformanceTest

  COMMON_DIR = File.expand_path(File.dirname(__FILE__)) + "/"

  # Algorithms of the queries, see benchmark_queries and calc_recall
  HNSW = "hnsw"               # approximate search with the HNSW index
  BRUTE_FORCE = "brute_force" # exact search

  FBENCH_RUNTIME = 10 # Seconds per query file
  RECALL_THREADS = 5

  # Sets the request parameters appended to the queries of a query case, both when benchmarking and when calculating
  # the recall: request parameter name => key of the value in the query case (a Symbol) or a fixed value, e.g.,
  #   {"hits" => :target_hits, "summary" => "minimal", "ranking.matching.approximateThreshold" => :approximate_threshold}
  # NearestNeighborRecallSearcher compares the first 'hits' hits, using the summary field 'id'.
  def set_request_parameters(parameters)
    @request_parameters = parameters
  end

  # Sets the format of the label of the benchmark and recall reports, with placeholders %{<key>} for the values of
  # the query case and %{algorithm} for the algorithm given to benchmark_queries and calc_recall,
  # e.g., "%{algorithm}-%{filter}-hr%{hit_ratio}-at%{approximate_threshold}".
  def set_label_format(format)
    @label_format = format
  end

  # Sets the parameters of the benchmark and recall reports (in addition to 'type' and 'label'):
  # report parameter name => key of the value in the query case, e.g., {"hit_ratio" => :hit_ratio}.
  def set_report_parameters(parameters)
    @report_parameters = parameters
  end

  def label(values)
    assert(@label_format, "The label format is not set, see set_label_format")
    format(@label_format, values)
  end

  # The parameters of the benchmark and recall reports for the query case
  def report_fillers(values)
    assert(@report_parameters, "The report parameters are not set, see set_report_parameters")
    [parameter_filler("label", label(values))] +
      @report_parameters.map { |name, key| parameter_filler(name, values.fetch(key)) }
  end

  # The request parameters appended to the queries of the query case (see set_request_parameters)
  def request_params(values)
    assert(@request_parameters, "The request parameters are not set, see set_request_parameters")
    @request_parameters.map { |name, value| "&#{name}=#{value.is_a?(Symbol) ? values.fetch(value) : value}" }.join
  end

  # Returns an application with the schema and NearestNeighborRecallSearcher in the default search chain.
  def create_app(sd_file, feeding_concurrency: 0.3)
    add_bundle(COMMON_DIR + "NearestNeighborRecallSearcher.java")
    searching = Searching.new
    searching.chain(Chain.new("default", "vespa").add(Searcher.new("ai.vespa.test.NearestNeighborRecallSearcher")))
    app = SearchApp.new.sd(sd_file).
      threads_per_search(1).
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(searching).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer")
    app.tune_searchnode({:feeding => {:concurrency => feeding_concurrency}})
    app
  end

  def container
    vespa.container.values.first
  end

  def print_hardware_details
    puts "Getting some hardware details from node #{container}"
    container.execute('numactl --show', :exceptiononfailure => false)
    container.execute('lscpu', :exceptiononfailure => false)
  end

  # Returns the path of the file on the node: <local_dir><name> if present (e.g., downloaded or generated for manual testing),
  # otherwise the file downloaded (once) from <s3_dir><name> in the S3 folder nearest-neighbor, i.e., from
  # https://data.vespa-cloud.com/tests/performance/nearest-neighbor/<s3_dir><name>.
  def find_or_download_file(name, node, local_dir:, s3_dir:)
    local_file = local_dir + name
    if File.exist?(local_file)
      puts "Using local file #{local_file}"
      return local_file
    end

    node_file = dirs.tmpdir + s3_dir + name
    if node.file?(node_file)
      puts "Using already downloaded file #{node_file}"
    else
      url = "https://data.vespa-cloud.com/tests/performance/nearest-neighbor/#{s3_dir}"
      puts "Downloading #{name} from #{url} ..."
      node.execute("mkdir -p #{File.dirname(node_file)}")
      node.fetchfiles(:testdata_url => url, :file => name, :destination_file => node_file)
    end
    node_file
  end

  # Returns the path of the file on the node: <local_dir><name> if present, otherwise the file decompressed (once) from
  # <name>.gz, which is found or downloaded with find_or_download_file.
  def find_or_download_compressed_file(name, node, local_dir:, s3_dir:)
    local_file = local_dir + name
    if File.exist?(local_file)
      puts "Using local file #{local_file}"
      return local_file
    end

    node_file = dirs.tmpdir + s3_dir + name
    if node.file?(node_file)
      puts "Using already decompressed file #{node_file}"
    else
      compressed = find_or_download_file(name + ".gz", node, local_dir: local_dir, s3_dir: s3_dir)
      puts "Decompressing #{compressed} to #{node_file}"
      node.execute("mkdir -p #{File.dirname(node_file)} && gzip -dc #{compressed} > #{node_file}.tmp && mv #{node_file}.tmp #{node_file}")
    end
    node_file
  end

  # Compiles the C++ source file on the node (once per node) and returns the path of the binary on the node.
  def compile_cpp(source_file, node)
    @compiled ||= {}
    @compiled[[source_file, node]] ||= begin
      binary = node.create_tmp_bin_dir + "/" + File.basename(source_file, ".cpp")
      node.execute("g++ -g -O3 -std=c++20 -o #{binary} #{source_file}")
      binary
    end
  end

  # Feeds the JSON feed file (on the admin server) and reports the feed performance.
  def feed_from_file(feed_file, fillers)
    profiler_start
    run_feeder(feed_file, [parameter_filler("type", "feed")] + fillers, :localfile => true)
    profiler_report("feed")
  end

  # Feeds the output of the command (a JSON array of operations, run on the admin server) and reports the feed performance,
  # e.g., for a document generator, which avoids writing large feed files.
  def feed_from_command(command, fillers)
    profiler_start
    run_stream_feeder(command, [parameter_filler("type", "feed")] + fillers)
    profiler_report("feed")
  end

  # Reports the fraction of the nodes in the HNSW graph of the tensor field that are not reachable from the entry point.
  def report_nni_stats(doc_type, tensor_field, fillers = [])
    uri = "/documentdb/#{doc_type}/subdb/ready/attribute/#{tensor_field}/tensor/nearest_neighbor_index"
    stats = vespa.search["search"].first.get_state_v1_custom_component(uri)
    puts "Nearest neighbor index statistics for '#{tensor_field}': #{stats}"
    write_report([parameter_filler("type", "nni")] + fillers +
                 [metric_filler("nni.unreachable", stats["reachability_analysis"]["nodes_not_found_pct"].to_f)])
  end

  # Benchmarks the query file (on the container) and calculates the recall of its first num_queries_for_recall queries.
  # algorithm: the algorithm of the queries in the query file, e.g., HNSW or BRUTE_FORCE (used in the label and the reports)
  # nnr: additional parameters for NearestNeighborRecallSearcher, e.g., {"exactField" => "embedding_f32"}.
  # Returns {:recall, :qps, :avg_ms, :p95_ms}.
  def benchmark_and_calc_recall(query_file, values, num_queries_for_recall, algorithm:, nnr: {})
    fancy_puts "Benchmarking and checking recall for #{label(values.merge({:algorithm => algorithm}))}"
    benchmark = benchmark_queries(query_file, values, algorithm: algorithm)
    recall = calc_recall(query_file, values, num_queries_for_recall, algorithm: algorithm, nnr: nnr)
    {:recall => recall,
     :qps => benchmark.metric('qps').to_f,
     :avg_ms => benchmark.metric('avgresponsetime').to_f,
     :p95_ms => benchmark.metric('95 percentile').to_f}
  end

  # Runs fbench with the query file (on the container) and returns the result (with the metrics 'qps', 'avgresponsetime', ...).
  # algorithm: the algorithm of the queries in the query file, e.g., HNSW or BRUTE_FORCE (used in the label and the report)
  def benchmark_queries(query_file, values, algorithm:, clients: 1)
    values = values.merge({:algorithm => algorithm})
    result_file = dirs.tmpdir + "fbench_result.#{label(values)}.txt"
    profiler_start
    result = run_fbench2(container,
                         query_file,
                         {:runtime => FBENCH_RUNTIME,
                          :clients => clients,
                          :append_str => request_params(values),
                          :result_file => result_file},
                         [parameter_filler("type", "query"), parameter_filler("clients", clients)] + report_fillers(values))
    profiler_report(label(values))
    container.execute("head -10 #{result_file}")
    result
  end

  # Calculates and reports the recall (in %) of the first num_queries queries of the query file (on the container).
  # algorithm: the algorithm of the queries in the query file, e.g., HNSW or BRUTE_FORCE (used in the label and the report)
  def calc_recall(query_file, values, num_queries, algorithm:, nnr: {})
    values = values.merge({:algorithm => algorithm})
    recall_file = dirs.tmpdir + "recall_queries.#{label(values)}.txt"
    container.execute("head -n #{num_queries} #{query_file} > #{recall_file}")
    local_recall_file = dirs.tmpdir + "local_recall_queries.#{label(values)}.txt"
    node = vespa.nodeproxies.values.find { |proxy| proxy.file?(recall_file) } # The node proxy of the container
    assert(node, "#{recall_file} not found on any node")
    node.copy_remote_file_to_local_file(recall_file, local_recall_file)
    queries = File.readlines(local_recall_file, chomp: true)
    assert_equal(num_queries, queries.size)

    target_hits = values.fetch(:target_hits)
    params = request_params(values) + "&nnr.enable=true" + nnr.map { |key, value| "&nnr.#{key}=#{value}" }.join
    batch_size = (queries.size.to_f / RECALL_THREADS).ceil
    threads = queries.each_slice(batch_size).map do |batch|
      Thread.new do
        batch.map do |query|
          # NearestNeighborRecallSearcher returns a single hit with the number of hits in common with the exact search
          result = search_with_timeout(20, query + params)
          assert_hitcount(result, 1)
          hit = result.hit[0]
          assert(hit.field["error"].nil?, "Error while calculating recall for query '#{query[0, 300]}...': #{hit.field["error"]}")
          hit.field["recall"].to_i
        end
      end
    end
    recalls = threads.flat_map(&:value).map { |recall| 100.0 * recall / target_hits }

    sorted = recalls.sort
    avg = recalls.sum / recalls.size
    median = (sorted[(sorted.size - 1) / 2] + sorted[sorted.size / 2]) / 2.0
    puts "recall: avg=#{avg}, median=#{median}, min=#{sorted.first}, max=#{sorted.last}, samples=[#{recalls.join(',')}]"
    write_report([parameter_filler("type", "recall")] + report_fillers(values) +
                 [metric_filler("recall.avg", avg), metric_filler("recall.median", median)])
    avg
  end

  # Prints a table with the header rows and the rows (arrays of values of the same length), each column right-aligned
  # to its widest value, followed by the notes.
  def print_table(title, headers, rows, notes = [])
    widths = (headers + rows).transpose.map { |column| column.map { |value| value.to_s.length }.max }
    format_row = lambda { |row| row.each_with_index.map { |value, i| value.to_s.rjust(widths[i]) }.join("  ") }
    lines = [title] + headers.map(&format_row)
    lines << "-" * lines.last.length
    lines += rows.map(&format_row)
    fancy_puts (lines + notes).join("\n")
  end

  def fancy_puts(str)
    puts '----'
    puts str
    puts '----'
  end

end
