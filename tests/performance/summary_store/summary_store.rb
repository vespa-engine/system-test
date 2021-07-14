# frozen_string_literal: true

require 'performance_test'
require 'performance/fbench'
require 'pp'
require 'document_set'
require 'document'

class SummaryStore < PerformanceTest
  def setup
    super
    set_owner('chunnoo')
    start
  end

  def compile_feed_generator
    @feed_generator = "#{dirs.tmpdir}feed_qenerator"
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -O3 -o #{@feed_generator} #{selfdir}feed_generator.cpp")
  end

  def compile_query_generator
    @query_generator = "#{dirs.tmpdir}query_qenerator"
    @queryfile = "#{dirs.tmpdir}generated_queries"
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -O3 -o #{@query_generator} #{selfdir}query_generator.cpp")
  end

  def warm_up
    feed_stream("#{@feed_generator} 100 100",
                route: '"combinedcontainer/chain.indexing null/default"')
  end

  def test_put_performance
    set_description('Test put performance')
    deploy("#{selfdir}app")
    compile_feed_generator
    warm_up
    profiler_start
    run_stream_feeder("#{@feed_generator} 100000 1024",
                      [parameter_filler('legend', 'test_put_performance')])
    profiler_report('test_put_performance')
  end

  def test_get_performance
    set_description('Test get performance for v1 api, queries and application with lz4 compression')
    deploy("#{selfdir}app")
    compile_feed_generator
    compile_query_generator
    run_stream_feeder("#{@feed_generator} 100000 1024", [])
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    container.execute("#{@query_generator} 100000 > #{@queryfile}")
    run_fbench(container, 128, 20, [parameter_filler('legend', 'ignore'),
                                    parameter_filler('tag', 'ignore1')])
    run_fbench(container, 128, 60, [parameter_filler('legend', 'query'),
                                    parameter_filler('tag', 'getv1api')])

    @queryfile = "#{dirs.tmpdir}query_hits"
    container.execute("echo \"/search/?query=doc_id:[100%3b101]\" > #{@queryfile}")
    run_fbench(container, 128, 20, [parameter_filler('legend', 'ignore'),
                                    parameter_filler('tag', 'ignore2')])
    run_fbench(container, 128, 60, [parameter_filler('legend', 'query'),
                                    parameter_filler('tag', 'summary')])

    deploy("#{selfdir}app_with_lz4_compression")
    vespa.search['contentnode'].first.trigger_flush
    vespa.adminserver.stop_base
    vespa.adminserver.start_base
    wait_until_ready
    run_fbench(container, 128, 20, [parameter_filler('legend', 'ignore'),
                                    parameter_filler('tag', 'ignore3')])
    run_fbench(container, 128, 60, [parameter_filler('legend', 'query'),
                                    parameter_filler('tag', 'summary_lz4')])
  end
end
