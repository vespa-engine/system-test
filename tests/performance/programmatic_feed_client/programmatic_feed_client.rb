# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'
require 'json'

class ProgrammaticFeedClientTest < PerformanceTest

  DOCUMENTS = 100000

  def setup
    set_owner('bjorncs')
    set_description('Benchmarking of programmatic feed clients in Java (vespa-feed-client vs vespa-http-client)')
    @graphs = [
      {
        :title => "Throughput",
        :x => 'loadgiver',
        :y => 'feeder.throughput',
        :historic => true
      }
    ]
  end

  def test_throughput
    container_node = deploy_test_app
    Executor.new(Environment.instance.vespa_short_hostname)
            .execute("cd java-feed-client; #{maven_command} --quiet package", self)
    tmp = "#{dirs.tmpdir}/#{File.basename(selfdir)}"
    jar_artifact_name = "java-feed-client-1.0.jar"
    container_node.copy("#{selfdir}/java-feed-client/target/#{jar_artifact_name}", tmp)
    main_class = "com.yahoo.vespa.systemtest.javafeedclient.VespaFeedClient"
    java_cmd =
      "java -cp #{jar_artifact_name} " +
      "-Dvespa.test.feed.route=default -Dvespa.test.feed.documents=#{DOCUMENTS} " +
        "-Dvespa.test.feed.connections=4 -Dvespa.test.feed.max-concurrent-streams-per-connection=128 " +
        "-Dvespa.test.feed.endpoint=https://#{container_node.hostname}:#{Environment.instance.vespa_web_service_port}/ " +
        "-Dvespa.test.feed.certificate=#{tls_env.certificate_file} " +
        "-Dvespa.test.feed.private-key=#{tls_env.private_key_file} " +
        "-Dvespa.test.feed.ca-certificate=#{tls_env.ca_certificates_file} #{main_class}"
    result = container_node.execute("cd #{tmp}; #{java_cmd}")
    json_result = JSON.parse(result.split("\n")[-1])
    write_report([json_to_filler(json_result)])
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
      container(container_cluster))
    start

    gw = @vespa.container.values.first
    wait_for_application(gw, output)
    gw
  end

  def teardown
    stop
  end
end
