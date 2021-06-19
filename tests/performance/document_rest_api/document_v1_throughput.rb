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
    1400
  end

  def setup
    super
    set_description("Stress test document/v1 API POST and GET")
    set_owner("jvenstad")
    @test_config = [
      {
        :http1 => {
          :clients => 1,
          :metrics => {'qps' => {'get' => {:y_min => 1400, :y_max => 1750}, 'post' => {:y_min => 540, :y_max => 760}}}
        }
      },
      {
        :http1 => {
          :clients => 8,
          :metrics => {'qps' => {'get' => {:y_min => 12500, :y_max => 14000}, 'post' => {:y_min => 6700, :y_max => 7500}}}
        }
      },
      {
        :http1 => {
          :clients => 64,
          :metrics => {'qps' => {'get' => {:y_min => 39000, :y_max => 42500}, 'post' => {:y_min => 24000, :y_max => 28000}}}
        }
      },
      {
        :http1 => {
          :clients => 128,
          :metrics => {'qps' => {'get' => {:y_min => 36500, :y_max => 39500}, 'post' => {:y_min => 27000, :y_max => 31500}}}
        }
      },
      {
        :http2 => {
          :clients => 1,
          :streams => 1,
          :threads => 1,
          :metrics => {'qps' => {'get' => {:y_min => 1240, :y_max => 1520}, 'post' => {:y_min => 620, :y_max => 750}}}
        }
      },
      {
        :http2 => {
          :clients => 1,
          :streams => 8,
          :threads => 1,
          :metrics => {'qps' => {'get' => {:y_min => 11900, :y_max => 13500}, 'post' => {:y_min => 6700, :y_max => 7400}}}
        }
      },
      {
        :http2 => {
          :clients => 1,
          :streams => 64,
          :threads => 1,
          :metrics => {'qps' => {'get' => {:y_min => 41500, :y_max => 45000}, 'post' => {:y_min => 25000, :y_max => 29000}}}
        }
      },
      {
        :http2 => {
          :clients => 1,
          :streams => 256,
          :threads => 1,
          :metrics => {'qps' => {'get' => {:y_min => 54000, :y_max => 63000}, 'post' => {:y_min => 30000, :y_max => 38000}}}
        }
      },
      {
        :http2 => {
          :clients => 8,
          :streams => 8,
          :threads => 8,
          :metrics => {'qps' => {'get' => {:y_min => 42000, :y_max => 46000}, 'post' => {:y_min => 25000, :y_max => 29000}}}
        }
      },
      {
        :http2 => {
          :clients => 8,
          :streams => 64,
          :threads => 8,
          :metrics => {'qps' => {'get' => {:y_min => 56000, :y_max => 66000}, 'post' => {:y_min => 33000, :y_max => 40000}}}
        }
      },
      {
        :http2 => {
          :clients => 64,
          :streams => 8,
          :threads => 16,
          :metrics => {'qps' => {'get' => {:y_min => 53500, :y_max => 64000}, 'post' => {:y_min => 31000, :y_max => 39000}}}
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

    queries_file = dirs.tmpdir + "queries.txt"
    qrserver.writefile((1..1024).map { |i| "/document/v1/test/text/docid/#{i}" }.join("\n"),
                       queries_file)

    data_file = dirs.tmpdir + "data.txt"
    qrserver.writefile("{ \"fields\": { \"text\": \"GNU#{"'s not UNIX" * (1 << 0) }\" } }",
                       data_file)

    @test_config.each do |config|
      ['post', 'get'].each do |http_method|
        post_data_file = if http_method == 'post' then data_file else nil end
        # Benchmark
        h2load = Perf::H2Load.new(@container)
        if config[:http1]
          clients = config[:http1][:clients]
          profiler_start
          http1_result = h2load.run_benchmark(
            clients: clients, threads: clients, concurrent_streams: 1, warmup: 10, duration: 30, uri_port: 4443,
            input_file: queries_file, protocols: ['http/1.1'], post_data_file: post_data_file)
          http1_fillers = [parameter_filler('clients', clients), parameter_filler('method', http_method),
                           parameter_filler('protocol', 'http1'), http1_result.filler]
          write_report(http1_fillers)
          profiler_report("http1-clients-#{clients}-method-#{http_method}")
        end

        if config[:http2]
          profiler_start
          clients = config[:http2][:clients]
          streams = config[:http2][:streams]
          http2_result = h2load.run_benchmark(
            clients: clients, threads: config[:http2][:threads], concurrent_streams: streams, warmup: 10, duration: 30, uri_port: 4443,
            input_file: queries_file, protocols: ['h2'], post_data_file: post_data_file)
          http2_fillers = [parameter_filler('clients', clients), parameter_filler('streams', streams),
                           parameter_filler('method', http_method), parameter_filler('protocol', 'http2'),
                           parameter_filler('clients-streams', "#{clients}-#{streams}"), http2_result.filler]
          write_report(http2_fillers)
          profiler_report("http2-clients#{clients}-streams-#{streams}-method-#{http_method}")
        end
      end
    end
  end

  def get_graphs
    graphs = []
    @test_config.each do |config|
      ['post', 'get'].each do |http_method|
        if config[:http1]
          config[:http1][:metrics].map do |metric_name, metric_limits|
            graphs.append({
              :x => 'protocol',
              :y => metric_name,
              :title => "HTTP/1.1 #{metric_name} - #{http_method} - #{config[:http1][:clients]} clients",
              :filter => { 'clients' => config[:http1][:clients], 'method' => http_method, 'protocol' => 'http1' },
              :historic => true
            }.merge(metric_limits[http_method] || {}))
          end
        end
        if config[:http2]
          config[:http2][:metrics].map do |metric_name, metric_limits|
            graphs.append({
              :x => 'protocol',
              :y => metric_name,
              :title => "HTTP/2 #{metric_name} - #{http_method} - #{config[:http2][:clients]} clients, #{config[:http2][:streams]} streams" \
                        "#{config[:backend] && " (#{config[:backend]} backend)"}",
              :filter => { 'clients' => config[:http2][:clients], 'streams' => config[:http2][:streams],
                           'method' => http_method, 'protocol' => 'http2' },
              :historic => true
            }.merge(metric_limits[http_method] || {}))
          end
        end
      end
    end
    ['post', 'get'].each do |http_method|
      graphs.append(
        {
          :x => 'clients',
          :y => 'qps',
          :title => "HTTP/1 qps - #{http_method}",
          :filter => { 'method' => http_method, 'protocol' => 'http1' },
          :historic => true
        })
      graphs.append(
        {
          :x => 'clients-streams',
          :y => 'qps',
          :title => "HTTP/2 qps - #{http_method}",
          :filter => { 'method' => http_method, 'protocol' => 'http2' },
          :historic => true
        })
    end

    graphs
  end

  def teardown
    super
  end

end
