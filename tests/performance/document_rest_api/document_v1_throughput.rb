# coding: utf-8
# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/container_app'
require 'app_generator/search_app'
require 'performance/h2load'

class DocumentV1Throughput < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    1200
  end

  def setup
    super
    set_description("Stress test document/v1 API POST and GET")
    set_owner("jvenstad")
    @test_config = [
      {
        :method => 'post',
        :data => "{ \"fields\": { \"text\": \"GNU's not UNIX\" } }",
        :http1 => {
          :clients => 1,
          :metrics => {'qps' => {}, '95p' => {}}
        },
        :http2 => {
          :clients => 1,
          :streams => 1,
          :threads => 1,
          :metrics => {'qps' => {}, '95p' => {}}
        }
      },
      {
        :method => 'get',
        :http1 => {
          :clients => 1,
          :metrics => {'qps' => {}, '95p' => {}}
        },
        :http2 => {
          :clients => 1,
          :streams => 1,
          :threads => 1,
          :metrics => {'qps' => {}, '95p' => {}}
        }
      },
      {
        :method => 'post',
        :data => "{ \"fields\": { \"text\": \"GNU's not UNIX\" } }",
        :http1 => {
          :clients => 8,
          :metrics => {'qps' => { :y_min => 2400, :y_max => 3300 }, '95p' => { :y_min => 1.4, :y_max => 1.7 }}
        },
        :http2 => {
          :clients => 2,
          :streams => 4,
          :threads => 2,
          :metrics => { 'qps' => { :y_min => 2400, :y_max => 3300 }, '95p' => { :y_min => 1.4, :y_max => 1.7 }}
        }
      },
      {
        :method => 'get',
        :http1 => {
          :clients => 8,
          :metrics => {'qps' => { :y_min => 6000, :y_max => 6800 }, '95p' => { :y_min => 0.6, :y_max => 0.9 }}
        },
        :http2 => {
          :clients => 2,
          :streams => 4,
          :threads => 2,
          :metrics => {'qps' => { :y_min => 6000, :y_max => 6800 }, '95p' => { :y_min => 0.6, :y_max => 0.9 }}
        }
      },
      {
        :method => 'post',
        :data => "{ \"fields\": { \"text\": \"GNU#{"'s not UNIX" * (1 << 10) }\" } }",
        :http1 => {
          :clients => 32,
          :metrics => {'qps' => {}, '95p' => {}}
        },
        :http2 => {
          :clients => 4,
          :streams => 8,
          :threads => 4,
          :metrics => {'qps' => {}, '95p' => {}}
        }
      },
      {
        :method => 'get',
        :http1 => {
          :clients => 32,
          :metrics => {'qps' => {}, '95p' => {}}
        },
        :http2 => {
          :clients => 4,
          :streams => 8,
          :threads => 4,
          :metrics => {'qps' => {}, '95p' => {}}
        }
      },
      {
        :method => 'post',
        :data => "{ \"fields\": { \"text\": \"GNU#{"'s not UNIX" * (1 << 10) }\" } }",
        :http1 => {
          :clients => 128,
          :metrics => {'qps' => { :y_min => 6100, :y_max => 6500 }, '95p' => { :y_min => 22, :y_max => 29 }}
        },
        :http2 => {
          :clients => 8,
          :streams => 16,
          :threads => 8,
          :metrics => {'qps' => { :y_min => 6100, :y_max => 6500 }, '95p' => { :y_min => 22, :y_max => 29 }}
        }
      },
      {
        :method => 'get',
        :http1 => {
          :clients => 128,
          :metrics => {'qps' => { :y_min => 31500, :y_max => 35000 }, '95p' => { :y_min => 4.5, :y_max => 5.3 }}
        },
        :http2 => {
          :clients => 128,
          :streams => 16,
          :threads => 8,
          :metrics => {'qps' => { :y_min => 31500, :y_max => 35000 }, '95p' => { :y_min => 4.5, :y_max => 5.3 }}
        }
      }
    ]
    @graphs = get_graphs
  end

  def test_throughput
    # Deploy a dummy app to get a reference to the container node, which is needed for uploading the certificate
    deploy_app(ContainerApp.new.container(Container.new))
    @container = @vespa.container.values.first

    # Generate TLS certificate with endpoint
    system("openssl req -nodes -x509 -newkey rsa:4096 -keyout #{dirs.tmpdir}cert.key -out #{dirs.tmpdir}cert.pem -days 365 -subj '/CN=#{@container.hostname}'")
    system("chmod 644 #{dirs.tmpdir}cert.key #{dirs.tmpdir}cert.pem")
    @container.copy("#{dirs.tmpdir}cert.key", dirs.tmpdir)
    @container.copy("#{dirs.tmpdir}cert.pem", dirs.tmpdir)

    # Deploy new app with TLS connector that does not require client to provided X.509 certificate
    deploy_app(
      SearchApp.new.monitoring("vespa", 60).
        container(
          Container.new("combinedcontainer").
            http(
              Http.new.
                server(Server.new('http', @container.http_port)).
                server(Server.new('https', '4443').
                  config(ConfigOverride.new("jdisc.http.connector").add("http2Enabled", true)).
                  ssl(Ssl.new(private_key_file = "#{dirs.tmpdir}cert.key", certificate_file = "#{dirs.tmpdir}cert.pem",
                              ca_certificates_file=nil, client_authentication='disabled')))).
            jvmargs('-Xms16g -Xmx16g').
            search(Searching.new).
            docproc(DocumentProcessing.new).
            gateway(ContainerDocumentApi.new)).
        admin_metrics(Metrics.new).
        indexing("combinedcontainer").
        sd(selfdir + "text.sd"))
    start

    benchmark_operations
  end

  def benchmark_operations
    qrserver = @vespa.container["combinedcontainer/0"]

    @test_config.each do |config|
      queries = (1..1024).map do |i|
        "/document/v1/test/text/docid/#{i}"
      end.join("\n")
      queries_file = dirs.tmpdir + "queries.txt"
      qrserver.writefile(queries, queries_file)
      post_data_file =
        if config[:method] == 'post'
          file_name = dirs.tmpdir + "data.txt"
          qrserver.writefile(config[:data], file_name)
          file_name
        else
          nil
        end

      # Benchmark
      h2load = Perf::H2Load.new(@container)
      if config[:http1]
        clients = config[:http1][:clients]
        profiler_start
        http1_result = h2load.run_benchmark(
          clients: clients, threads: clients, concurrent_streams: 1, warmup: 10, duration: 30, uri_port: 4443,
          input_file: queries_file, protocols: ['http/1.1'], post_data_file: post_data_file)
        http1_fillers = [parameter_filler('clients', clients), parameter_filler('method', config[:method]),
                         parameter_filler('protocol', 'http1'), http1_result.filler]
        write_report(http1_fillers)
        profiler_report("http1-clients-#{clients}-method-#{config[:method]}")
      end

      if config[:http2]
        profiler_start
        clients = config[:http2][:clients]
        streams = config[:http2][:streams]
        http2_result = h2load.run_benchmark(
          clients: clients, threads: config[:http2][:threads], concurrent_streams: streams, warmup: 10, duration: 30, uri_port: 4443,
          input_file: queries_file, protocols: ['h2'], post_data_file: post_data_file)
        http2_fillers = [parameter_filler('clients', clients), parameter_filler('streams', streams),
                         parameter_filler('method', config[:method]), parameter_filler('protocol', 'http2'), http2_result.filler]
        write_report(http2_fillers)
        profiler_report("http2-clients#{clients}-streams-#{streams}-method-#{config[:method]}")
      end

    end
  end

  def get_graphs
    graphs = []
    @test_config.each do |config|
      if config[:http1]
        config[:http1][:metrics].map do |metric_name, metric_limits|
          graphs.append({
            :x => 'protocol',
            :y => metric_name,
            :title => "HTTP/1.1 #{metric_name} - #{config[:http1][:clients]} clients",
            :filter => { 'clients' => config[:http1][:clients], 'method' => config[:method], 'protocol' => 'http1' },
            :historic => true
          }.merge(metric_limits))
        end
      end
      if config[:http2]
        config[:http2][:metrics].map do |metric_name, metric_limits|
          graphs.append({
            :x => 'protocol',
            :y => metric_name,
            :title => "HTTP/2 #{metric_name} - #{config[:http2][:clients]} clients with #{config[:http2][:streams]} streams each",
            :filter => { 'clients' => config[:http2][:clients], 'streams' => config[:http2][:streams],
                         'method' => config[:method], 'protocol' => 'http2' },
            :historic => true
          }.merge(metric_limits))
        end
      end
    end
    graphs
  end

  def teardown
    super
  end

end
