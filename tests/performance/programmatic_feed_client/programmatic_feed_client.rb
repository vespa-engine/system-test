# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'json'

class ProgrammaticFeedClientTest < PerformanceTest

  DOCUMENTS = 100000

  DEFAULT_ROUTE = 'default'
  DUMMY_ROUTE = 'null/default'
  VESPA_HTTP_CLIENT = 'vespa-http-client'
  VESPA_FEED_CLIENT = 'vespa-feed-client'

  def setup
    set_owner('bjorncs')
    set_description('Benchmarking of programmatic feed clients in Java (vespa-feed-client vs vespa-http-client)')
    @graphs = [
      {
        :title => "Throughput (route=#{DEFAULT_ROUTE})",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'route' => DEFAULT_ROUTE},
        :historic => true
      },
      {
        :title => "Throughput (route=#{DUMMY_ROUTE})",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'route' => DUMMY_ROUTE},
        :historic => true
      },
      {
        :title => "Throughput #{VESPA_HTTP_CLIENT}",
        :x => 'route',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_HTTP_CLIENT},
        :historic => true,
      },
      {
        :title => "Throughput #{VESPA_FEED_CLIENT}",
        :x => 'route',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT},
        :historic => true
      },
      {
        :title => "Throughput #{VESPA_HTTP_CLIENT} (route=#{DEFAULT_ROUTE})",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => { 'loadgiver' => VESPA_HTTP_CLIENT, 'route' => DEFAULT_ROUTE},
        :historic => true,
      },
      {
        :title => "Throughput #{VESPA_FEED_CLIENT} (route=#{DEFAULT_ROUTE})",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT, 'route' => DEFAULT_ROUTE},
        :historic => true
      },
      {
        :title => "Throughput #{VESPA_HTTP_CLIENT} (route=#{DUMMY_ROUTE})",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => { 'loadgiver' => VESPA_HTTP_CLIENT, 'route' => DUMMY_ROUTE},
        :historic => true,
      },
      {
        :title => "Throughput #{VESPA_FEED_CLIENT} (route=#{DUMMY_ROUTE})",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :filter => {'loadgiver' => VESPA_FEED_CLIENT, 'route' => DUMMY_ROUTE},
        :historic => true
      }
    ]
  end

  def test_throughput
    container_node = deploy_test_app
    build_feed_client

    run_benchmark(container_node, DEFAULT_ROUTE, "VespaHttpClient")
    run_benchmark(container_node, DEFAULT_ROUTE, "VespaFeedClient")
    run_benchmark(container_node, DUMMY_ROUTE, "VespaHttpClient")
    run_benchmark(container_node, DUMMY_ROUTE, "VespaFeedClient")
  end

  private
  def build_feed_client
    vespa.adminserver.execute("cd #{java_client_src_root}; #{maven_command} --quiet package")
  end

  private
  def run_benchmark(container_node, vespa_route, program_name)
    write_report(
      [
        json_to_filler(run_benchmark_program(container_node, vespa_route, program_name)),
        parameter_filler('route', vespa_route)
      ]
    )
  end

  private
  def run_benchmark_program(container_node, vespa_route, main_class)
    java_cmd =
      "java -cp java-feed-client-1.0.jar " +
        "-Dvespa.test.feed.route=#{vespa_route} -Dvespa.test.feed.documents=#{DOCUMENTS} " +
        "-Dvespa.test.feed.connections=4 -Dvespa.test.feed.max-concurrent-streams-per-connection=128 " +
        "-Dvespa.test.feed.endpoint=https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/ " +
        "-Dvespa.test.feed.certificate=#{tls_env.certificate_file} " +
        "-Dvespa.test.feed.private-key=#{tls_env.private_key_file} " +
        "-Dvespa.test.feed.ca-certificate=#{tls_env.ca_certificates_file} " +
        "com.yahoo.vespa.systemtest.javafeedclient.#{main_class}"
    result = vespa.adminserver.execute("cd #{java_client_src_root}/target; #{java_cmd}")
    JSON.parse(result.split("\n")[-1])
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
      jvmargs("-Xms4096m -Xmx4096m").
      search(Searching.new).
      gateway(ContainerDocumentApi.new).
      config(ConfigOverride.new("container.handler.threadpool").add("maxthreads", 4))
    output = deploy_app(SearchApp.new.
      cluster(SearchCluster.new.sd(SEARCH_DATA+"music.sd")).
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
