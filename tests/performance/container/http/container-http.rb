# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'app_generator/container_app'
require 'http_client'
require 'performance_test'
require 'performance/fbench'
require 'performance/h2load'
require 'pp'


class ContainerHttp < PerformanceTest

  KEY_FILE = 'cert.key'
  CERT_FILE = 'cert.crt'

  PERSISTENT = 'persistent'
  NON_PERSISTENT = 'nonpersistent'

  HTTP1 = 'http1'
  HTTP2 = 'http2'

  def setup
    set_owner('bjorncs')
    # Bundle with HelloWorld and AsyncHelloWorld handler
    @bundledir= selfdir + 'java'
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})

    # Deploy a dummy app to get a reference to the container node, which is needed for uploading the certificate
    deploy_container_app(ContainerApp.new.container(Container.new))
    @container = @vespa.container.values.first

    # Generate TLS certificate with endpoint
    system("PATH=/opt/vespa-deps/bin:$PATH; openssl req -nodes -x509 -newkey rsa:4096 -keyout #{dirs.tmpdir}#{KEY_FILE} -out #{dirs.tmpdir}#{CERT_FILE} -days 365 -subj '/CN=#{@container.hostname}'", exception: true)
    system("chmod 644 #{dirs.tmpdir}#{KEY_FILE} #{dirs.tmpdir}#{CERT_FILE}")
    @container.copy("#{dirs.tmpdir}#{KEY_FILE}", dirs.tmpdir)
    @container.copy("#{dirs.tmpdir}#{CERT_FILE}", dirs.tmpdir)
  end


  def test_container_http_performance
    deploy_test_app(access_logging: false)

    set_description('Test basic HTTP performance of container')
    run_http1_tests
    run_http2_tests
  end

  def test_container_http_performance_with_logging
    deploy_test_app(access_logging: true)
    set_description('Test basic HTTP performance of container with logging enabled')
    run_http1_tests
  end

  def deploy_test_app(access_logging:)
    app = ContainerApp.new.container(
      Container.new.
        component(AccessLog.new(if access_logging then "vespa" else "disabled" end).
          fileNamePattern("logs/vespa/access/QueryAccessLog.default")).
        handler(Handler.new('com.yahoo.performance.handler.HelloWorldHandler').
          binding('http://*/HelloWorld').
          bundle('performance')).
        http(
          Http.new.
            server(
              Server.new('http', @container.http_port)).
            server(
              Server.new('https', '4443').
                config(ConfigOverride.new("jdisc.http.connector").
                  add("http2Enabled", true)).
                ssl(Ssl.new(private_key_file = "#{dirs.tmpdir}#{KEY_FILE}", certificate_file = "#{dirs.tmpdir}#{CERT_FILE}", ca_certificates_file=nil, client_authentication='disabled')))))
    deploy_container_app(app)
  end

  def deploy_container_app(app)
    output = deploy_app(app)
    start
    wait_for_application(@vespa.container.values.first, output)
  end

  def run_http1_tests
    run_h2load_benchmark(128, 1, 10, HTTP1)
    run_h2load_benchmark(32, 1, 5, HTTP1)
    run_h2load_benchmark(1, 1, 5, HTTP1)
    run_fbench_benchmark(32, NON_PERSISTENT)
  end

  def run_http2_tests
    run_h2load_benchmark(128, 1, 10, HTTP2)
    run_h2load_benchmark(8,  16, 5, HTTP2)
    run_h2load_benchmark(8,  32, 5, HTTP2)
    run_h2load_benchmark(4,  32, 5, HTTP2)
    run_h2load_benchmark(4,  64, 5, HTTP2)
    run_h2load_benchmark(4, 128, 5, HTTP2)
    run_h2load_benchmark(1,  32, 5, HTTP2)
    run_h2load_benchmark(1,  64, 5, HTTP2)
    run_h2load_benchmark(1, 128, 5, HTTP2)
    run_h2load_benchmark(1, 256, 5, HTTP2)
  end

  def run_fbench_benchmark(clients, connection)
    @container.copy(selfdir + "hello.txt", dirs.tmpdir)
    @queryfile = dirs.tmpdir + "hello.txt"

    profiler_start
    run_fbench(@container, clients, 40,
               [parameter_filler('connection', connection), parameter_filler('protocol', HTTP1),
                parameter_filler('benchmark-tag', "#{HTTP1}-#{clients}-1")],
               {:disable_http_keep_alive => connection == NON_PERSISTENT})
    profiler_report(connection)
    end

  def run_h2load_benchmark(clients, concurrent_streams, warmup, protocol)
    perf = Perf::System.new(@container)
    perf.start
    h2load = Perf::H2Load.new(@container)
    result = h2load.run_benchmark(clients: clients, threads: [clients, 16].min, concurrent_streams: concurrent_streams,
                                  warmup: warmup, duration: 30, uri_port: 4443, uri_path: '/HelloWorld',
                                  protocols: [if protocol == HTTP2 then 'h2' else 'http/1.1' end])
    perf.end
    write_report([result.filler, perf.fill, parameter_filler('connection', PERSISTENT), parameter_filler('protocol', protocol),
                  parameter_filler('benchmark-tag', "#{protocol}-#{clients}-#{concurrent_streams}")])
  end

end
