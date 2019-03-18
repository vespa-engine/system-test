# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'pp'


class CanvassWarmup < PerformanceTest

  def initialize(*args)
    super(*args)
    @app = selfdir + 'app'
    @queryfile = nil
    @bundledir= selfdir + 'java'
  end

  def setup
    set_owner('bergum')
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})
  end

  def setup_and_deploy(app)
    deploy(app)
    start
  end


  def test_warmup_hard
    setup_and_deploy(@app)
    set_description('Test 200 queries after container has started and repeat with 200 queries after first 200 has succeeded')
    @graphs = [
      {
        :title => 'Min response time for 200 first and 200 second query',
        :x => 'legend',
        :y => 'minresponsetime',
        :historic => true
      },
      {

        :title => 'Average latency',
        :x => 'legend',
        :y => 'latency',
        :historic => true
      },
      {
        :x => 'legend',
        :y => 'cpuutil',
        :historic => true
      },
      {
        :x => 'legend',
        :y => 'memory.rss',
        :historic => true
      }
    ]
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    @queryfile = selfdir + 'yql.txt'
    profiler_start
    run_fbench(container, 200, 20, [parameter_filler('legend', 'test_warmup_hard'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))], {:times_reuse_query_files => 0 })
    profiler_report('test_warmup_hard')


    profiler_start
    run_fbench(container, 200, 20, [parameter_filler('legend', 'test_warmup_hard_second'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))], {:times_reuse_query_files => 0 })
    profiler_report('test_warmup_hard_second')

  end
end
