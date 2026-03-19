# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'performance/fbench'
require 'environment'

class ContainerGcTest < PerformanceTest

  GC_CONFIGS = {
    'parallel' => '-XX:+UseParallelGC -XX:MaxTenuringThreshold=15 -XX:NewRatio=1',
    'g1'       => '-XX:+UseG1GC',
    'zgc'      => '-XX:+UseZGC -XX:+AlwaysPreTouch -XX:-ZUncommit'
  }

  def initialize(*args)
    super(*args)
    @app = selfdir + 'gcapp'
    @bundledir = selfdir + 'java'
  end

  def setup
    set_owner('bjorncs')
    add_bundle_dir(@bundledir, 'performance', {:mavenargs => '-Dmaven.test.skip=true'})
  end

  def timeout_seconds
    1800
  end

  def test_container_gc_comparison
    set_description('Compare GC algorithms (Parallel, G1, ZGC) under GC pressure with 24GB heap, measuring tail latency')

    first_run = true
    GC_CONFIGS.each do |name, gc_options|
      unless first_run
        vespa.stop_base
      end
      deploy_with_gc(gc_options)
      start
      first_run = false
      container = vespa.qrserver['0'] || vespa.container.values.first
      queryfile = dirs.tmpdir + '/queries.txt'
      yql_template = 'select * from sources * where text contains "$words()" AND weightedSet(text, { ' + (['"$words()": 1'] * 10).join(', ') + ' });'
      container.write_queries(template: yql_template, yql: true, count: 1000000,
                              parameters: { 'model.locale' => 'en-US' }, filename: queryfile)

      run_gc_benchmark(container, queryfile, name)
    end
  end

  private

  def deploy_with_gc(gc_options)
    deploy(@app, nil, :sed_vespa_services =>
      "sed -e 's,\\$VESPA_HOME,#{Environment.instance.vespa_home},g' " +
      "-e 's,GC_OPTIONS_PLACEHOLDER,#{gc_options},g'")
  end

  def run_gc_benchmark(container, queryfile, gc_name)
    system_fbench = Perf::System.new(container)
    system_fbench.start

    fbench = Perf::Fbench.new(container, container.name, container.http_port)
    fbench.clients = 128
    fbench.runtime = 90
    fbench.ignore_first = 30
    fbench.request_per_ms = 10
    fbench.single_query_file = true
    fbench.query(queryfile)

    system_fbench.end

    fillers = [
      fbench.fill,
      system_fbench.fill,
      parameter_filler('gc_algorithm', gc_name),
      parameter_filler('legend', gc_name)
    ]
    write_report(fillers)
  end

end
