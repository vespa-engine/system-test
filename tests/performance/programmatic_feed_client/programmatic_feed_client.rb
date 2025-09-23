# Copyright Vespa.ai. All rights reserved.
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
    container_node.logctl("container:com.yahoo.messagebus.DynamicThrottlePolicy", "debug=on")
    vespa_destination_start
    @maven_tmp_dir = "#{dirs.tmpdir}/#{File.basename(selfdir)}"
    build_feed_client

    run_benchmark(container_node, "VespaFeedClient",   TINY)
    run_benchmark(container_node, "VespaJsonFeeder",   TINY)
    run_benchmark(container_node, "VespaFeedClient",  LARGE)
    run_benchmark(container_node, "VespaJsonFeeder",  LARGE)
  end

  private
  def build_feed_client
    vespa.adminserver.copy("#{java_client_src_root}", @maven_tmp_dir)
    install_maven_parent_pom(vespa.adminserver)
    vespa.adminserver.execute("cd #{@maven_tmp_dir}; #{maven_command} --quiet package")
  end

  private
  def run_benchmark(container_node, program_name, size, compression = nil)
    label = "#{program_name}-#{compression.nil? ? "" : "#{compression}-"}#{size}b"
    cpu_monitor = Perf::System.new(container_node)
    cpu_monitor.start
    profiler_start
    result, pid = run_benchmark_program(container_node, program_name, label, size, compression)
    profiler_report(label, { program_name => [ pid ] })
    cpu_monitor.end
    write_report(
      [
        json_to_filler(result),
        parameter_filler('size', size),
        parameter_filler('label', label),
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
  def run_benchmark_program(container_node, main_class, label, size, compression)
    out_file = "#{dirs.tmpdir}/#{label}.out"
    err_file = "#{dirs.tmpdir}/#{label}.err"
    java_cmd =
      "java #{perfmap_jvmarg} -cp #{@maven_tmp_dir}/target/java-feed-client-1.0.jar " +
        "-Dvespa.test.feed.route=#{DUMMY_ROUTE} " +
        "-Dvespa.test.feed.documents=#{DOCUMENTS} " +
        "-Dvespa.test.feed.warmup.seconds=#{10} " +
        "-Dvespa.test.feed.benchmark.seconds=#{30} " +
        "-Dvespa.test.feed.document-text='#{generate_text(size)}' " +
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


end
