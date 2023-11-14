# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
    num_queries = 200
    set_description("Test #{num_queries}  queries after container has started and repeat with #{num_queries} queries after first #{num_queries} has succeeded")
    container = (vespa.qrserver['0'] or vespa.container.values.first)

#    result = search("/search/?yql=select%20%2A%20from%20sources%20%2A%20where%20text%20contains%20%22foo%22%3B&format=json&tracelevel=1&trace.timestamps").json
#    puts "Result Query #1: " + JSON.pretty_generate(result)

#    result = search("/search/?yql=select%20%2A%20from%20sources%20%2A%20where%20text%20contains%20%22foo%22%3B&format=json&tracelevel=1&trace.timestamps").json
#    puts "Result Query #2: " + JSON.pretty_generate(result)

    @queryfile = selfdir + 'yql.txt'
    profiler_start
    run_fbench(container, num_queries, 20, [parameter_filler('legend', 'test_warmup_hard'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))], {:times_reuse_query_files => 0 })

    profiler_report('test_warmup_hard')
    profiler_start
    run_fbench(container, num_queries, 20, [parameter_filler('legend', 'test_warmup_hard_second'),
                                     metric_filler('memory.rss', container.memusage_rss(container.get_pid))], {:times_reuse_query_files => 0 })
    profiler_report('test_warmup_hard_second')

  end
end
