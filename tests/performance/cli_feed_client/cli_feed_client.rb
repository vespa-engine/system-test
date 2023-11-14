# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'concurrent'
require 'json'

class CliFeedClientTest < PerformanceTest

  DOCUMENTS = 2000000
  TINY = 10
  MEDIUM = 1000
  LARGE = 10000

  DUMMY_ROUTE = 'null/default'

  def timeout_seconds
    1800
  end

  def setup
    set_owner('mpolden')
    set_description('Benchmarking of the Vespa CLI feed client and vespa-feed-client (Java implementation)')
  end

  def test_throughput
    container_node = deploy_test_app
    vespa_destination_start

    run_benchmark(container_node, "vespa-cli-feed",    TINY)
    run_benchmark(container_node, "vespa-cli-feed",    MEDIUM)
    run_benchmark(container_node, "vespa-cli-feed",    LARGE)
    run_benchmark(container_node, "vespa-feed-client", TINY)
    run_benchmark(container_node, "vespa-feed-client", MEDIUM)
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
    complete = thread_pool.wait_for_termination(300)
    puts("###### STDERR #####\n#{vespa.adminserver.readfile(err_file)}")
    result = vespa.adminserver.readfile(out_file)
    puts("###### STDOUT #####\n#{result}")
    raise "Failed to complete benchmark within 5 minutes" unless complete
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

  def teardown
    super
  end

end
