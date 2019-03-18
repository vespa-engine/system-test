# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/container_app'
require 'performance/httperf'
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

  def run_httperf(system, httperf)
    system.start
    httperf.query('/HelloWorld')
    system.end
  end

  def deploy_helloworld_app()
    jdisc = Container.new.
        handler(Handler.new("com.yahoo.vespatest.HelloWorld").
                    binding("http://*/HelloWorld")).
        jvmargs('-Xms387m -Xmx6g -XX:ThreadStackSize=1024')


    output = deploy_app(ContainerApp.new.
                            container(jdisc))

#    output = deploy_app(ContainerApp.new.
#                   container(Container.new.
#                                 jetty(true).
#                                 handler(Handler.new("com.yahoo.vespatest.HelloWorld").
#                                             binding("http://*/HelloWorld")).
#                                 jvmargs('-Xms387m -Xmx6g -XX:ThreadStackSize=1024')))  # Replicates defaults for jdisc test

    start
    wait_for_application(@vespa.container.values.first, output)
  end

  def run_container_warmup_httperf(num_conns, num_calls)
    set_description("Test container warmup with httperf.")
    legend = "warmup_httperf"

    min_time = 1.0
    max_time = 4.0

    setup_graphs(legend, min_time, max_time)

    container = vespa.container.values.first
    httperf = get_httperf(container)
    httperf.num_conns = num_conns
    httperf.num_calls = num_calls

    system = create_perf_system(container)

    times = Array.new
    request_rates = Array.new
    total_time = 0
    (0..120).each { |i|
      run_httperf(system, httperf)
      total_time += httperf.parser.total_test_duration

      request_rates[i] = httperf.parser.request_rate
      times[i] = total_time
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

    add_factory_report_plugin("Warmup qps", create_graph_plugin(times, request_rates))
  end

  def create_graph_plugin(times, request_rates)
    scripts = "<script src='https://www.google.com/jsapi' " +
        "type='text/javascript'></script>\n" +
        "<script src='//ajax.googleapis.com/ajax/libs/jquery/1.10.2/" +
        "jquery.min.js' type='text/javascript'></script>\n" +
        "<script src='/javascripts/plugin_chart.js' type='text/javascript'>" +
        "</script>\n"

    plugin = scripts +
        "<div id='plugin_chart' title='Query rate from startup' " +
        "data=\"[['time', 'qps'], "


    for i in (0..request_rates.size-1)
      plugin += "['#{times[i]}',#{request_rates[i]}],"
    end
    plugin += "]\" xlabel='time since first query' ylabel='qps'></div>\n"
  end

  def setup_graphs(legend, min_time, max_time)
    @graphs = [
        {
            :x => 'time',
            :y => 'request-rate',
            :historic => false
        },
        {
            :x => 'time',
            :y => 'request-rate-sma-short',
            :historic => false
        },
        {
            :x => 'time',
            :y => 'request-rate-sma-long',
            :historic => false
        },
        {
            :x => 'legend', # works for historic graphs
            :y => 'stable_time',
            :title => 'Build vs. warm-up period length [s]',
            :historic => true,
            :y_min => min_time,
            :y_max => max_time,
            :filter => {
                :legend => legend + '-historic_stable_time'
            }
        }
    ]
  end

  def test_container_warmup_jetty
    deploy_helloworld_app
    run_container_warmup_httperf(1, 1000)
  end

  def teardown
    super
  end
end
