# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

# Base class for performance tests of nearest neighbor search, independent of the data set:
# deploying an application with NearestNeighborRecallSearcher, feeding (a feed file or the output of a command),
# benchmarking query files with fbench, and calculating the recall.
#
# Usage:
#   1. Deploy a schema (with a document summary 'minimal' containing 'id') and start Vespa:
#        setup_test("cohere_filtered")
#   2. Feed the documents:
#        feed_from_command("#{compile_generator("make_filtered_docs", vespa.adminserver)} --vectors docs.fvecs ...", fillers)
#   3. Map the values of a benchmark to request parameters and labels:
#        set_request_parameters({"hits" => :target_hits, "ranking.matching.approximateThreshold" => :approximate_threshold})
#        set_label_format("%{name}-th%{target_hits}-hr%{hit_ratio}")
#   4. For each benchmark, write a query file and benchmark it with its values (reported as parameters):
#        values = {:name => "hnsw", :approximate => true, :target_hits => 100, :explore_hits => 0, :hit_ratio => 0.01}
#        benchmark_and_calc_recall(query_file, values, num_queries_for_recall)
#
# A data set module feeds the documents and writes the queries (with the generators) for each kind of test it supports,
# see AnnFiltered and AnnGeo.
class AnnBase < PerformanceTest

  FBENCH_RUNTIME = 10 # Seconds per query file
  RECALL_THREADS = 5

  # Sets the request parameters appended to the queries of a benchmark, both when benchmarking and when calculating
  # the recall: request parameter name => key of a value of the benchmark (a Symbol) or a fixed value, e.g.,
  #   {"hits" => :target_hits, "summary" => "minimal", "ranking.matching.approximateThreshold" => :approximate_threshold}
  # NearestNeighborRecallSearcher compares the first 'hits' hits, using the summary field 'id'.
  def set_request_parameters(parameters)
    @request_parameters = parameters
  end

  # Sets the format of the label of the benchmark and recall reports, with placeholders %{<key>} for the values of
  # the benchmark, e.g., "%{name}-%{filter}-hr%{hit_ratio}-at%{approximate_threshold}".
  def set_label_format(format)
    @label_format = format
  end

  def label(values)
    assert(@label_format, "The label format is not set, see set_label_format")
    format(@label_format, values)
  end

  # The parameters of the benchmark and recall reports: the label and all values of the benchmark, named by their keys,
  # e.g., 'hit_ratio' for :hit_ratio.
  def report_fillers(values)
    [parameter_filler("label", label(values))] +
      values.map { |key, value| parameter_filler(key.to_s, value) }
  end

  # The request parameters appended to the queries of the benchmark (see set_request_parameters)
  def request_params(values)
    assert(@request_parameters, "The request parameters are not set, see set_request_parameters")
    @request_parameters.map { |name, value| "&#{name}=#{value.is_a?(Symbol) ? values.fetch(value) : value}" }.join
  end

  # Returns an application with the schema and NearestNeighborRecallSearcher in the default search chain.
  def create_app(sd_file, feeding_concurrency: 0.5, threads_per_search: 1)
    add_bundle(selfdir + "NearestNeighborRecallSearcher.java")
    searching = Searching.new
    searching.chain(Chain.new("default", "vespa").add(Searcher.new("ai.vespa.test.NearestNeighborRecallSearcher")))
    app = SearchApp.new.sd(sd_file).
      threads_per_search(threads_per_search).
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(searching).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      indexing("combinedcontainer")
    app.tune_searchnode({:feeding => {:concurrency => feeding_concurrency}})
    app
  end

  # Deploys the schema schemas/<schema>/test.sd and starts Vespa. The test sets @num_documents (the first vectors of
  # the data set are fed), @num_queries_for_benchmark (the queries in each query file), and @num_queries_for_recall (the first
  # queries of each query file used to calculate the recall).
  # substitutions: placeholders %{<key>} in the schema to replace, e.g., {"QUANTIZATION_BITS" => 4} (see templated_schema).
  def setup_test(schema, threads_per_search: 1, substitutions: {})
    assert(@num_queries_for_recall <= @num_queries_for_benchmark)
    sd_file = templated_schema(selfdir + "schemas/#{schema}/test.sd", substitutions)
    deploy_app(create_app(sd_file, threads_per_search: threads_per_search))
    start
    print_hardware_details
  end

  # Returns the path of a copy of the schema file with each placeholder %{<key>} replaced by its value in substitutions,
  # or the schema file itself if there are no substitutions. Fails if a key is not in the schema or a placeholder is left.
  def templated_schema(sd_file, substitutions)
    return sd_file if substitutions.empty?
    sd = File.read(sd_file)
    substitutions.each do |key, value|
      assert(sd.include?("%{#{key}}"), "Placeholder %{#{key}} not found in #{sd_file}")
      sd = sd.gsub("%{#{key}}", value.to_s)
    end
    left = sd[/%\{\w+\}/]
    assert(left.nil?, "No substitution for placeholder #{left} in #{sd_file}")
    gen_dir = dirs.tmpdir + "templated_schema/"
    FileUtils.mkdir_p(gen_dir)
    gen_file = gen_dir + File.basename(sd_file)
    File.write(gen_file, sd)
    gen_file
  end

  def container
    vespa.container.values.first
  end

  def print_hardware_details
    puts "Getting some hardware details from node #{container}"
    container.execute('numactl --show', :exceptiononfailure => false)
    container.execute('lscpu', :exceptiononfailure => false)
  end

  # Returns the path on the node of the data file at the path relative to nearest_neighbor_ng/, e.g., cohere-data/queries.fvecs:
  # the local file if present (e.g., downloaded or generated for manual testing), otherwise the file downloaded (once) from
  # the same path in the S3 folder https://data.vespa-cloud.com/tests/performance/nearest-neighbor/.
  def find_or_download_file(path, node)
    local_file = selfdir + path
    if File.exist?(local_file)
      puts "Using local file #{local_file}"
      return local_file
    end

    node_file = dirs.tmpdir + path
    if node.file?(node_file)
      puts "Using already downloaded file #{node_file}"
    else
      url = "https://data.vespa-cloud.com/tests/performance/nearest-neighbor/#{File.dirname(path)}"
      name = File.basename(path)
      puts "Downloading #{name} from #{url} ..."
      node.execute("mkdir -p #{File.dirname(node_file)}")
      node.fetchfiles(:testdata_url => url, :file => name, :destination_file => node_file)
    end
    node_file
  end

  # Returns the path on the node of the data file at the path (see find_or_download_file): the local file if present,
  # otherwise the file decompressed (once) from <path>.gz, which is found or downloaded with find_or_download_file.
  def find_or_download_compressed_file(path, node)
    local_file = selfdir + path
    if File.exist?(local_file)
      puts "Using local file #{local_file}"
      return local_file
    end

    node_file = dirs.tmpdir + path
    if node.file?(node_file)
      puts "Using already decompressed file #{node_file}"
    else
      compressed = find_or_download_file(path + ".gz", node)
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

  # Compiles the generator generators/<name>.cpp on the node (once per node) and returns the path of the binary.
  # The generators are C++ programs from parquet-vectors (see the readme there). They read the vectors from .fvecs files
  # of any dimension, and take the name of the tensor field as an option (see --help of each program).
  def compile_generator(name, node)
    compile_cpp(selfdir + "generators/#{name}.cpp", node)
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

  # Benchmarks the query file (on the container). Returns {:qps, :avg_ms, :p95_ms}.
  def benchmark(query_file, values)
    fancy_puts "Benchmarking #{label(values)}"
    result = benchmark_queries(query_file, values)
    {:qps => result.metric('qps').to_f,
     :avg_ms => result.metric('avgresponsetime').to_f,
     :p95_ms => result.metric('95 percentile').to_f}
  end

  # Benchmarks the query file (on the container) and calculates the recall of its first num_queries_for_recall queries.
  # nnr: additional parameters for NearestNeighborRecallSearcher, e.g., {"exactField" => "embedding_f32"}.
  # Returns {:recall, :qps, :avg_ms, :p95_ms}.
  def benchmark_and_calc_recall(query_file, values, num_queries_for_recall, nnr: {})
    result = benchmark(query_file, values)
    result.merge({:recall => calc_recall(query_file, values, num_queries_for_recall, nnr: nnr)})
  end

  # Runs fbench with the query file (on the container) and returns the result (with the metrics 'qps', 'avgresponsetime', ...).
  def benchmark_queries(query_file, values, clients: 1)
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
  def calc_recall(query_file, values, num_queries, nnr: {})
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

  BENCHMARK_HEADERS = ["qps", "avg ms", "p95 ms"]
  BENCHMARK_NOTE = "(qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)"
  RESULT_HEADERS = ["recall"] + BENCHMARK_HEADERS
  RESULT_NOTE = "(recall: average recall in %, qps: queries per second with 1 client, avg/p95 ms: average/95th percentile response time)"

  def benchmark_cells(result)
    [format('%.1f', result[:qps]), format('%.2f', result[:avg_ms]), format('%.2f', result[:p95_ms])]
  end

  def result_cells(result)
    [format('%.1f', result[:recall])] + benchmark_cells(result)
  end

  def results_title(parameters)
    "Results for #{@num_documents} documents: " + parameters.map { |key, value| "#{key} #{value}" }.join(", ")
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
