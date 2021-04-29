require 'app_generator/container_app'
require 'http_client'
require 'performance_test'
require 'performance/fbench'
require 'pp'


class ContainerHttp < PerformanceTest

  KEY_FILE = 'cert.key'
  CERT_FILE = 'cert.crt'
  STANDARD = 'standard'
  ASYNC_WRITE = 'asyncwrite'
  NON_PERSISTENT = 'nonpersistent'

  def initialize(*args)
    super(*args)
    @queryfile = nil
    @bundledir= selfdir + 'java'
  end

  def setup
    set_owner('bjorncs')
    # Bundle with HelloWorld and AsyncHelloWorld handler
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})

    # Deploy a dummy app to get a reference to the container node, which is needed for uploading the certificate
    deploy_container_app(ContainerApp.new.container(Container.new))
    @container = @vespa.container.values.first

    # Generate TLS certificate with endpoint
    system("openssl req -nodes -x509 -newkey rsa:4096 -keyout #{dirs.tmpdir}#{KEY_FILE} -out #{dirs.tmpdir}#{CERT_FILE} -days 365 -subj '/CN=#{@container.hostname}'")
    system("chmod 644 #{dirs.tmpdir}#{KEY_FILE} #{dirs.tmpdir}#{CERT_FILE}")
    @container.copy("#{dirs.tmpdir}#{KEY_FILE}", dirs.tmpdir)
    @container.copy("#{dirs.tmpdir}#{CERT_FILE}", dirs.tmpdir)
  end


  def test_container_http_performance
    deploy_test_app(access_logging: false)

    set_description('Test basic HTTP performance of container')
    @graphs = [
        {
            :title => 'QPS all combined',
            :x => 'legend',
            :y => 'qps',
            :historic => true
        },
        {
            :title => 'QPS HTTP/1.1',
            :filter => {'legend' => STANDARD},
            :x => 'legend',
            :y => 'qps',
            :y_min => 145000,
            :y_max => 180000,
            :historic => true
        },
        {
            :title => 'QPS HTTP/1.1 with async write',
            :filter => {'legend' => ASYNC_WRITE },
            :x => 'legend',
            :y => 'qps',
            :y_min => 125000,
            :y_max => 150000,
            :historic => true
        },
        {
            :title => 'QPS HTTP/1.1 without keep-alive',
            :filter => {'legend' => NON_PERSISTENT },
            :x => 'legend',
            :y => 'qps',
            :y_min => 3300,
            :y_max => 3500,
            :historic => true
        },
        {
            :x => 'legend',
            :y => 'latency',
            :historic => true
        },
        {
            :x => 'legend',
            :y => 'cpuutil',
            :historic => true
        }
    ]
    run_test
  end

  def test_container_http_performance_with_logging
    deploy_test_app(access_logging: true)
    set_description('Test basic HTTP performance of container with logging enabled')
    @graphs = [
        {
            :title => 'QPS all combined',
            :x => 'legend',
            :y => 'qps',
            :historic => true
        },
        {
            :title => 'QPS HTTP/1.1',
            :filter => {'legend' => STANDARD},
            :x => 'legend',
            :y => 'qps',
            :y_min => 105000,
            :y_max => 140000,
            :historic => true
        },
        {
            :title => 'QPS HTTP/1.1 with async write',
            :filter => {'legend' => ASYNC_WRITE },
            :x => 'legend',
            :y => 'qps',
            :y_min => 105000,
            :y_max => 135000,
            :historic => true
        },
        {
            :title => 'QPS HTTP/1.1 without keep-alive',
            :filter => {'legend' => NON_PERSISTENT },
            :x => 'legend',
            :y => 'qps',
            :y_min => 3200,
            :y_max => 3500,
            :historic => true
        },
        {
            :x => 'legend',
            :y => 'latency',
            :historic => true
        },
        {
            :x => 'legend',
            :y => 'cpuutil',
            :historic => true
        }
    ]
    run_test
  end

  def deploy_test_app(access_logging:)
    app = ContainerApp.new.container(
      Container.new.
        component(AccessLog.new(if access_logging then "vespa" else "disabled" end).
          fileNamePattern("logs/vespa/qrs/QueryAccessLog.default")).
        handler(Handler.new('com.yahoo.performance.handler.HelloWorldHandler').
          binding('http://*/HelloWorld').
          bundle('performance')).
        handler(Handler.new('com.yahoo.performance.handler.AsyncHelloWorldHandler').
          binding('http://*/AsyncHelloWorld').
          bundle('performance')).
        http(
          Http.new.
            server(
              Server.new('http', @container.http_port)).
            server(
              Server.new('https', '4443').ssl(
                Ssl.new(private_key_file = "#{dirs.tmpdir}#{KEY_FILE}", certificate_file = "#{dirs.tmpdir}#{CERT_FILE}", ca_certificates_file=nil, client_authentication='disabled')))))
    deploy_container_app(app)
  end

  def deploy_container_app(app)
    output = deploy_app(app)
    start
    wait_for_application(@vespa.container.values.first, output)
  end

  def run_test
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    container.copy(selfdir + "hello.txt", dirs.tmpdir)
    sync_req_file = dirs.tmpdir + "hello.txt"
    container.copy(selfdir + "async_hello.txt", dirs.tmpdir)
    async_req_file = dirs.tmpdir + "async_hello.txt"

    @queryfile = sync_req_file
    run_fbench(container, 128, 20, []) # warmup

    profiler_start
    run_fbench(container, 128, 120, [parameter_filler('legend', STANDARD)])
    profiler_report(STANDARD)

    @queryfile = async_req_file
    profiler_start
    run_fbench(container, 128, 120, [parameter_filler('legend', ASYNC_WRITE)])
    profiler_report(ASYNC_WRITE)

    @queryfile = sync_req_file
    profiler_start
    run_fbench(container, 32, 120, [parameter_filler('legend', NON_PERSISTENT)], {:disable_http_keep_alive => true})
    profiler_report(NON_PERSISTENT)
  end

end
