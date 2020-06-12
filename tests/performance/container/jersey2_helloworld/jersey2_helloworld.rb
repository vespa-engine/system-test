# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/container_app'
require 'app_generator/rest_api'
require 'pp'
require 'environment'

class Jersey2HelloWorld < PerformanceTest
  include AppGenerator

  module TestMode
    CLIENTS_8   = 'fbench_hello_8'
    CLIENTS_128 = 'fbench_hello_128'
  end

  def setup
    super
    set_owner("gjoranv")
    set_description("Test JDisc performance with basic jersey helloworld")

    add_bundle_dir(selfdir + "hello", "basic_jersey2")
    app = ContainerApp.new.container(
              Container.new.
                  jvmargs('-Xms16g -Xmx16g').
                  rest_api(RestApi.new('rest-api').
                               bundle(Bundle.new('basic_jersey2'))).
                  component(AccessLog.new("disabled")))
    deploy_my_app(app)
  end

  def create_perf_system(container)
    Perf::System.new(container)
  end

  def deploy_my_app(app)
    output = deploy_app(app)
    start
    @container = vespa.container.values.first
    wait_for_application(@container, output)
  end

  def copy_query_file
    queryfile_dir = "#{Environment.instance.vespa_home}/tmp/performancetest_jersey_helloworld/"
    queryfile_name = "fbench-queries.txt"
    vespa.adminserver.copy(selfdir + queryfile_name, queryfile_dir)
    @queryfile = queryfile_dir + queryfile_name
  end

  def warmup_container
    fbench = Perf::Fbench.new(@container, @container.name, @container.http_port)
    fbench.times_reuse_query_files = 25000
    fbench.max_line_size = 1
    fbench.query(@queryfile)
  end

  def run_performance_fbench(clients, runtime, custom_fillers=[])
    @graphs = get_graphs('qps', 'latency')
    run_fbench(@container, clients, runtime, custom_fillers)
  end

  def get_graphs(reply_rate_name, latency_name)
    [
        {
            :x => 'build',
            :y => reply_rate_name,
            :historic => true
        },
        {
            :x => 'build',
            :y => reply_rate_name,
            :y_min => 58000,
            :y_max => 66000,
            :historic => true,
            :filter => {
                'build' => TestMode::CLIENTS_8
            }
        },
        {
            :x => 'build',
            :y => reply_rate_name,
            :y_min => 200000,
            :y_max => 212000,
            :historic => true,
            :filter => {
                'build' => TestMode::CLIENTS_128
            }
        },
        {
            :x => 'build',
            :y => latency_name,
            :historic => true
        },
        {
            :x => 'build',
            :y => 'cpuutil',
            :historic => true
        }
    ]
  end

  def test_jersey2_helloworld
    copy_query_file
    warmup_container
    run_performance_fbench(8, 60, [parameter_filler("build", TestMode::CLIENTS_8)])
    run_performance_fbench(128, 60, [parameter_filler("build", TestMode::CLIENTS_128)])
  end

  def teardown
    super
  end
end
