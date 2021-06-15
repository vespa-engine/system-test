# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'json'

class ProgrammaticFeedClientTest < PerformanceTest

  DOCUMENTS = 1000000
  TINY = 10
  SMALL = 100
  MEDIUM = 1000
  LARGE = 10000

  DUMMY_ROUTE = 'null/default'
  VESPA_HTTP_CLIENT = 'vespa-http-client'
  VESPA_FEED_CLIENT = 'vespa-feed-client'
  VESPA_JSON_FEEDER = 'vespa-json-feeder'

  def timeout_seconds
    1800
  end

  def setup
    set_owner('bjorncs')
    set_description('Benchmarking of programmatic feed clients in Java (vespa-feed-client vs vespa-http-client)')
    @graphs = [
      {
        :title => "Throughput, all combinations",
        :x => 'label',
        :y => 'feeder.throughput',
        :historic => true
      },
      {
        :title => "CPU util, all combinations",
        :x => 'label',
        :y => 'cpuutil',
        :historic => true,
      },
      {
        :title => "Average latency #{VESPA_FEED_CLIENT}",
        :x => 'label',
        :y => 'feeder.avglatency',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT},
        :historic => true
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => { 'loadgiver' => VESPA_HTTP_CLIENT, 'size' => LARGE},
        :historic => true,
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT, 'size' => LARGE},
        :historic => true
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => { 'loadgiver' => VESPA_HTTP_CLIENT, 'size' => MEDIUM},
        :historic => true,
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT, 'size' => MEDIUM},
        :historic => true
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => { 'loadgiver' => VESPA_HTTP_CLIENT, 'size' => SMALL},
        :historic => true,
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT, 'size' => SMALL},
        :historic => true
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => { 'loadgiver' => VESPA_HTTP_CLIENT, 'size' => TINY},
        :historic => true,
      },
      {
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT, 'size' => TINY},
        :historic => true
      },
    ]
  end

  def test_throughput
    container_node = deploy_test_app
    build_feed_client

    run_benchmark(container_node, "VespaHttpClient",   TINY,  2)
    run_benchmark(container_node, "VespaFeedClient",   TINY, 16)
    run_benchmark(container_node, "VespaJsonFeeder",   TINY, 16)
    run_benchmark(container_node, "VespaHttpClient",  SMALL,  2)
    run_benchmark(container_node, "VespaFeedClient",  SMALL, 16)
    run_benchmark(container_node, "VespaHttpClient", MEDIUM,  2)
    run_benchmark(container_node, "VespaFeedClient", MEDIUM, 16)
    run_benchmark(container_node, "VespaHttpClient",  LARGE,  2)
    run_benchmark(container_node, "VespaFeedClient",  LARGE, 16)
    run_benchmark(container_node, "VespaJsonFeeder",  LARGE, 16)
  end

  private
  def build_feed_client
    vespa.adminserver.execute("cd #{java_client_src_root}; #{maven_command} --quiet package")
  end

  private
  def run_benchmark(container_node, program_name, size, connections)
    label = "#{program_name}-#{size}b"
    cpu_monitor = Perf::System.new(container_node)
    cpu_monitor.start
    profiler_start
    result, pid = run_benchmark_program(container_node, program_name, label, size, connections)
    profiler_report(label, { "program_name" => [ pid ] })
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
  def run_benchmark_program(container_node, main_class, label, size, connections)
    out_file = "#{label}.out"
    err_file = "#{label}.err"
    java_cmd =
      "java #{perfmap_agent_jvmarg} -cp #{java_client_src_root}/target/java-feed-client-1.0.jar " +
        "-Dvespa.test.feed.route=#{DUMMY_ROUTE} " +
        "-Dvespa.test.feed.documents=#{DOCUMENTS} " +
        "-Dvespa.test.feed.document-text='#{generate_text(size)}' " +
        "-Dvespa.test.feed.connections=#{connections} " +
        "-Dvespa.test.feed.max-concurrent-streams-per-connection=64 " +
        "-Dvespa.test.feed.endpoint=https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/ " +
        "-Dvespa.test.feed.certificate=#{tls_env.certificate_file} " +
        "-Dvespa.test.feed.private-key=#{tls_env.private_key_file} " +
        "-Dvespa.test.feed.ca-certificate=#{tls_env.ca_certificates_file} " +
        "com.yahoo.vespa.systemtest.javafeedclient.#{main_class} 1> #{out_file} 2> #{err_file}"
    pid = vespa.adminserver.execute_bg("exec #{java_cmd}") # exec to let java inherit the subshell's PID.
    vespa.adminserver.waitpid(pid)
    puts(vespa.adminserver.readfile(err_file))
    [ JSON.parse(vespa.adminserver.readfile(out_file).split("\n")[-1]), pid ]
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
      jvmargs('-Xms16g -Xmx16g').
      search(Searching.new).
      gateway(ContainerDocumentApi.new).
      config(ConfigOverride.new("container.handler.threadpool").add("maxthreads", 4))
    output = deploy_app(SearchApp.new.
      sd(selfdir + 'text.sd').
      container(container_cluster).
      generic_service(GenericService.new('devnull', "#{Environment.instance.vespa_home}/bin/vespa-destination --instant --silent 1000000000")))
    start

    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    gw
  end

  private
  def java_client_src_root
    selfdir + "java-feed-client"
  end

  def teardown
    stop
  end
end
