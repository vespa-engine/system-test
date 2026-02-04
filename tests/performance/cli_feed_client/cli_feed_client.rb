# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'concurrent'
require 'json'

class CliFeedClientTest < PerformanceTest

  DOCUMENTS = 2_000_000
  TINY = 10
  LARGE = 10_000

  DUMMY_ROUTE = 'null/default'

  N_TENSOR_QUERIES = 10

  def timeout_seconds
    1800
  end

  def setup
    set_owner('hmusum, bragehk')
    set_description('Benchmarking of the Vespa CLI feed client and vespa-feed-client (Java implementation)')
    @vespa_destination_pid = nil
  end

  def test_tensor_query_throughput
    container_node = deploy_tensor_app
    feed_tensor_documents(container_node, 3200)
    run_tensor_query_benchmark(container_node, N_TENSOR_QUERIES)
  end

  def test_throughput
    container_node = deploy_test_app
    vespa_destination_start

    run_benchmark(container_node, "vespa-cli-feed",    TINY)
    run_benchmark(container_node, "vespa-cli-feed",    LARGE)
    run_benchmark(container_node, "vespa-feed-client", TINY)
    run_benchmark(container_node, "vespa-feed-client", LARGE)
  end

  private
  def run_benchmark(container_node, program_name, size)
    label = "#{program_name}-#{size}b"
    cpu_monitor = Perf::System.new(container_node)
    cpu_monitor.start
    profiler_start
    result, pid = run_benchmark_program(container_node, program_name, label, size, DOCUMENTS)
    profiler_report(label, { program_name => [ pid ] })
    cpu_monitor.end
    write_report(
      [
        json_to_filler(result),
        parameter_filler('size', size),
        parameter_filler('label', label),
        cpu_monitor.fill
      ]
    )
    puts(JSON.pretty_generate(result))
  end

  private
  def generate_text(size)
    template = "These are just bytes that flow across the network interface, so nothing too fancy :> "
    (template * (size / template.length + 1)).slice(0, size)
  end

  private
  def run_benchmark_program(container_node, program_name, label, size, doc_count)
    out_file = "#{dirs.tmpdir}/#{label}.out"
    err_file = "#{dirs.tmpdir}/#{label}.err"
    feed_file = "#{dirs.tmpdir}/docs_#{doc_count}_#{size}b.json"
    endpoint = "https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/"
    if program_name == "vespa-cli-feed"
      feed_cmd = "env "+
                 "VESPA_CLI_DATA_PLANE_TRUST_ALL=true " +
                 "VESPA_CLI_DATA_PLANE_CA_CERT_FILE=#{tls_env.ca_certificates_file} " +
                 "VESPA_CLI_DATA_PLANE_CERT_FILE=#{tls_env.certificate_file} " +
                 "VESPA_CLI_DATA_PLANE_KEY_FILE=#{tls_env.private_key_file} " +
                 "vespa feed " +
                 "--target=#{endpoint} " +
                 "--route=#{DUMMY_ROUTE} " +
                 "#{feed_file} " +
                 "1> #{out_file} 2> #{err_file}"
    else
      feed_cmd = "vespa-feed-client " +
                 "--silent " +
                 "--disable-ssl-hostname-verification " +
                 "--ca-certificates #{tls_env.ca_certificates_file} " +
                 "--certificate #{tls_env.certificate_file} " +
                 "--private-key #{tls_env.private_key_file} " +
                 "--endpoint #{endpoint} " +
                 "--route #{DUMMY_ROUTE} " +
                 "--file #{feed_file} " +
                 "2> #{out_file}"
    end
    vespa.adminserver.write_document_operations(:put,
                                                { :fields => { :text => generate_text(size) } },
                                                "id:text:text::mydoc-",
                                                doc_count,
                                                feed_file)
    pid = vespa.adminserver.execute_bg("exec #{feed_cmd}") # exec to let process inherit the subshell's PID
    thread_pool = Concurrent::FixedThreadPool.new(1)
    thread_pool.post { vespa.adminserver.waitpid(pid) }
    thread_pool.shutdown
    complete = thread_pool.wait_for_termination(600)
    puts("###### STDERR #####\n#{vespa.adminserver.readfile(err_file)}")
    result = vespa.adminserver.readfile(out_file)
    puts("###### STDOUT #####\n#{result}")
    raise "Failed to complete benchmark within 10 minutes" unless complete
    return format_output(JSON.parse(result)), pid
  end

  private
  def format_output(data)
    durationMillis = data["feeder.seconds"] * 1000
    throughput = data["feeder.ok.count"] / durationMillis * 1000
    {
      "feeder.runtime" => durationMillis,
      "feeder.okcount" => data["feeder.ok.count"],
      "feeder.errorcount" => data["feeder.error.count"],
      "feeder.exceptions" => data["http.exception.count"],
      "feeder.bytessent" => data["http.request.bytes"],
      "feeder.bytesreceived" => data["http.response.bytes"],
      "feeder.throughput" => throughput,
      "feeder.minlatency" => data["http.response.latency.millis.min"],
      "feeder.avglatency" => data["http.response.latency.millis.avg"],
      "feeder.maxlatency" => data["http.response.latency.millis.max"],
    }

  end

  private
  def json_to_filler(json)
    Proc.new do |result|
      json.each do |key, value|
        if key.start_with?("feeder.")
          result.add_metric(key, value.to_s)
        else
          result.add_parameter(key, value.to_s)
        end
      end
    end
  end

  private
  def deploy_test_app
    container_cluster = Container.new("dpcluster1").
      jvmoptions('-Xms16g -Xmx16g').
      search(Searching.new).
      documentapi(ContainerDocumentApi.new).
      component(AccessLog.new("disabled")).
      config(ConfigOverride.new("container.handler.threadpool").add("maxthreads", 4))
    output = deploy_app(SearchApp.new.
      sd(selfdir + 'text.sd').
      container(container_cluster))
    start
    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    gw
  end

  private
  def feed_tensor_documents(container_node, num_docs)
    tensor_docs_s3 = "mips-data/paragraph_docs.400k.json"
    # Use a permanent local cache directory for the data file
    local_data_dir = "#{selfdir}/data"
    vespa.adminserver.execute("mkdir -p #{local_data_dir}")
    full_file = "#{local_data_dir}/paragraph_docs.400k.json"

    # Download from S3 only if the file doesn't exist locally
    if vespa.adminserver.execute("test -f #{full_file}; echo $?").to_i != 0
      downloaded_file = download_file_from_s3(tensor_docs_s3, vespa.adminserver, "nearest-neighbor")
      vespa.adminserver.execute("cp #{downloaded_file} #{full_file}")
    end

    subset_file = "#{dirs.tmpdir}/paragraph_docs.#{num_docs}.json"

    lines_to_extract = num_docs + 1
    vespa.adminserver.execute("(head -#{lines_to_extract} #{full_file} | head -c -2; echo ''; echo ']') > #{subset_file}", :exceptiononfailure => true)

    endpoint = "https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/"
    feed_cmd = "env " +
               "VESPA_CLI_DATA_PLANE_TRUST_ALL=true " +
               "VESPA_CLI_DATA_PLANE_CA_CERT_FILE=#{tls_env.ca_certificates_file} " +
               "VESPA_CLI_DATA_PLANE_CERT_FILE=#{tls_env.certificate_file} " +
               "VESPA_CLI_DATA_PLANE_KEY_FILE=#{tls_env.private_key_file} " +
               "vespa feed " +
               "--target=#{endpoint} " +
               "#{subset_file}"
    vespa.adminserver.execute(feed_cmd)
  end

  private
  def run_tensor_query_benchmark(container_node, num_queries)
    endpoint = "https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/"
    label = "vespa-cli-tensor-query"
    cpu_monitor = Perf::System.new(container_node)
    cpu_monitor.start
    profiler_start

    start_time = Time.now
    num_queries.times do
      run_single_tensor_query(endpoint)
    end
    end_time = Time.now
    duration_seconds = end_time - start_time

    profiler_report(label)
    cpu_monitor.end

    qps = num_queries / duration_seconds
    write_report(
      [
        Proc.new do |result|
          result.add_metric('tensor.query.qps', qps.to_s)
          result.add_metric('tensor.query.count', num_queries.to_s)
          result.add_metric('tensor.query.duration_seconds', duration_seconds.to_s)
        end,
        parameter_filler('label', label),
        cpu_monitor.fill
      ]
    )
    puts("Tensor query benchmark: #{num_queries} queries in #{duration_seconds}s (#{qps} QPS")
  end

  private
  def run_single_tensor_query(endpoint)
    out_file = "#{dirs.tmpdir}/tensor_query.out"
    err_file = "#{dirs.tmpdir}/tensor_query.err"
    query_cmd = "env " +
                "VESPA_CLI_DATA_PLANE_TRUST_ALL=true " +
                "VESPA_CLI_DATA_PLANE_CA_CERT_FILE=#{tls_env.ca_certificates_file} " +
                "VESPA_CLI_DATA_PLANE_CERT_FILE=#{tls_env.certificate_file} " +
                "VESPA_CLI_DATA_PLANE_KEY_FILE=#{tls_env.private_key_file} " +
                "/home/bragehk/git/vespa/client/go/bin/vespa query " +
                "--target=#{endpoint} " +
                "--verbose " +
                "'yql=select * from paragraph where id >= 0' " +
                "'hits=3200' " +
                "> #{out_file} 2> #{err_file}"

    vespa.adminserver.execute(query_cmd)
  end

  private
  def deploy_tensor_app
    container_cluster = Container.new("dpcluster1").
      jvmoptions('-Xms16g -Xmx16g -XX:NewRatio=1').
      search(Searching.new).
      documentapi(ContainerDocumentApi.new).
      component(AccessLog.new("disabled"))
    output = deploy_app(SearchApp.new.
      sd(selfdir + 'paragraph.sd').
      search_dir(selfdir + 'app').
      container(container_cluster).
      threads_per_search(1))
    start
    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    gw
  end

end
