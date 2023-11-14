# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/container_app'
require 'performance/filter'
require 'performance/proc_tools'
require 'pp'


class ContainerWarmup < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def prepare
    super
  end

  def setup
    super
    set_owner("gjoranv")
    add_bundle(selfdir + "HelloWorld.java")
  end

  def create_perf_system(container)
    Perf::System.new(container)
  end

  def deploy_helloworld_app()
    jdisc = Container.new.
        handler(Handler.new("com.yahoo.vespatest.HelloWorld").
                    binding("http://*/HelloWorld")).
        jvmoptions('-Xms387m -Xmx6g -XX:ThreadStackSize=1024')


    output = deploy_app(ContainerApp.new.
                            container(jdisc))

#    output = deploy_app(ContainerApp.new.
#                   container(Container.new.
#                                 handler(Handler.new("com.yahoo.vespatest.HelloWorld").
#                                             binding("http://*/HelloWorld")).
#                                 jvmoptions('-Xms387m -Xmx6g -XX:ThreadStackSize=1024')))  # Replicates defaults for jdisc test

    start
    wait_for_application(@vespa.container.values.first, output)
  end

  def run_container_warmup(num_conns, num_calls)
    set_description("Test container warmup with fbench")
    legend = "warmup_fbench"

    queryfile_dir = "#{Environment.instance.vespa_home}/tmp/performancetest_container_warmup_jetty/"
    queryfile_name = "fbench-queries.txt"
    vespa.adminserver.copy(selfdir + queryfile_name, queryfile_dir)
    query_file = queryfile_dir + queryfile_name

    min_time = 3.3
    max_time = 5.8

    container = vespa.container.values.first
    fbench = Perf::Fbench.new(container, container.name, container.http_port)
    fbench.clients = num_conns
    fbench.times_reuse_query_files = num_calls
    fbench.include_handshake = false

    system = create_perf_system(container)

    times = Array.new
    request_rates = Array.new
    total_time = 0
    (0..120).each { |i|
      system.start
      fbench.query(query_file)
      qps = fbench.qps
      total_time += (num_calls / qps)
      request_rates[i] = qps
      times[i] = total_time
      system.end
    }

    short_window = 25
    long_window = 100
    short_window_smoothed = Perf::Filter.sma(request_rates, short_window)
    long_window_smoothed = Perf::Filter.sma(request_rates, long_window)
    for i in (0..request_rates.size-1)
      write_report([parameter_filler('legend', legend),
                    parameter_filler('time', (times[i] * 100).to_i / 100.0),
                    metric_filler('request-rate', request_rates[i]),
                    metric_filler('request-rate-sma-short', short_window_smoothed[i]),
                    metric_filler('request-rate-sma-long', long_window_smoothed[i])])
    end

    stable_threshold = long_window_smoothed.max * 0.9
    puts("Stable threshold: " + stable_threshold.to_s)
    stable_index = Perf::ProcTools.first_intersection(short_window_smoothed, stable_threshold)
    puts("Time before stable: " + times[stable_index].to_s)
    write_report([parameter_filler('legend', legend + '-historic_stable_time'),
                  metric_filler('stable_time', times[stable_index])])
  end

  def test_container_warmup_jetty
    deploy_helloworld_app
    run_container_warmup(1, 1000)
  end

  def teardown
    super
  end
end
