# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'concurrent'
require 'json'

class ProgrammaticFeedClientTest < PerformanceTest

  DOCUMENTS = 2000000
  TINY = 10
  LARGE = 10000

  DUMMY_ROUTE = 'null/default'

  def timeout_seconds
    1800
  end

  def setup
    set_owner('bjorncs')
    set_description('Benchmarking of the programmatic feed client vespa-feed-client in Java')
  end

  def test_throughput
    container_node = deploy_test_app
    vespa_destination_start
    build_feed_client

    run_benchmark(container_node, "VespaFeedClient",   TINY, 32)
    run_benchmark(container_node, "VespaJsonFeeder",   TINY, 32)
    run_benchmark(container_node, "VespaFeedClient",  LARGE, 32)
    run_benchmark(container_node, "VespaJsonFeeder",  LARGE, 32)
  end

  private
  def build_feed_client
    vespa.adminserver.execute("cd #{java_client_src_root}; #{maven_command} --quiet package")
  end

  private
  def run_benchmark(container_node, program_name, size, connections, compression = nil)
    label = "#{program_name}-#{compression.nil? ? "" : "#{compression}-"}#{size}b"
    cpu_monitor = Perf::System.new(container_node)
    cpu_monitor.start
    profiler_start
    result, pid = run_benchmark_program(container_node, program_name, label, size, connections, compression)
    profiler_report(label, { program_name => [ pid ] })
    cpu_monitor.end
    write_report(
      [
        json_to_filler(result),
        parameter_filler('size', size),
        parameter_filler('label', label),
        parameter_filler('clients', connections),
        parameter_filler('compression', compression.nil? ? "default" : compression),
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
  def run_benchmark_program(container_node, main_class, label, size, connections, compression)
    out_file = "#{label}.out"
    err_file = "#{label}.err"
    java_cmd =
      "env LD_PRELOAD=$VESPA_HOME/lib64/vespa/malloc/libvespamallocd.so " +
      "java #{perfmap_agent_jvmarg} -cp #{java_client_src_root}/target/java-feed-client-1.0.jar " +
        "-Dvespa.test.feed.route=#{DUMMY_ROUTE} " +
        "-Dvespa.test.feed.documents=#{DOCUMENTS} " +
        "-Dvespa.test.feed.warmup.seconds=#{10} " +
        "-Dvespa.test.feed.benchmark.seconds=#{30} " +
        "-Dvespa.test.feed.document-text='#{generate_text(size)}' " +
        "-Dvespa.test.feed.connections=#{connections} " +
        "-Dvespa.test.feed.max-concurrent-streams-per-connection=4096 " +
        "-Dvespa.test.feed.endpoint=https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/ " +
        "-Dvespa.test.feed.certificate=#{tls_env.certificate_file} " +
        "-Dvespa.test.feed.private-key=#{tls_env.private_key_file} " +
        "-Dvespa.test.feed.ca-certificate=#{tls_env.ca_certificates_file} " +
        "#{compression.nil? ? "" : "-Dvespa.test.feed.compression=#{compression} "}" +
        "com.yahoo.vespa.systemtest.javafeedclient.#{main_class} 1> #{out_file} 2> #{err_file}"
    pid = vespa.adminserver.execute_bg("exec #{java_cmd}") # exec to let java inherit the subshell's PID.
    thread_pool = Concurrent::FixedThreadPool.new(1)
    thread_pool.post { vespa.adminserver.waitpid(pid) }
    thread_pool.shutdown
    complete = thread_pool.wait_for_termination(300)
    puts("###### STDERR #####\n#{vespa.adminserver.readfile(err_file)}")
    result = vespa.adminserver.readfile(out_file)
    puts("###### STDOUT #####\n#{result}")
    raise "Failed to complete benchmark within 5 minutes" unless complete
    [ JSON.parse(result.split("\n")[-1]), pid ]
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
  def java_client_src_root
    selfdir + "java-feed-client"
  end

  def teardown
    super
  end

end
