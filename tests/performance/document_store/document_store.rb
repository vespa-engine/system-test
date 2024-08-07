# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'performance/fbench'
require 'pp'
require 'document_set'
require 'document'

class DocumentStoreTest < PerformanceTest
  def setup
    super
    set_owner('chunnoo')
  end

  def compile_feed_generator
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    tmp_bin_dir = container.create_tmp_bin_dir
    @feed_generator = "#{tmp_bin_dir}/feed_generator"
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -O3 -o #{@feed_generator} #{selfdir}feed_generator.cpp")
  end

  def compile_query_generator
    @queryfile = "#{dirs.tmpdir}generated_queries"
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    tmp_bin_dir = container.create_tmp_bin_dir
    @query_generator = "#{tmp_bin_dir}/query_generator"
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -O3 -o #{@query_generator} #{selfdir}query_generator.cpp")
  end

  def warm_up
    feed_stream("#{@feed_generator} 100 100",
                route: '"combinedcontainer/chain.indexing null/default"')
  end

  def test_put_performance
    set_description('Test put performance for string field')
    deploy("#{selfdir}app")
    start
    vespa_destination_start
    compile_feed_generator
    warm_up
    profiler_start
    run_stream_feeder("#{@feed_generator} 100000 1024",
                      [parameter_filler('legend', 'test_put_performance')])
    profiler_report('test_put_performance')
  end

  def test_get_performance
    set_description('Test get performance for string field using document v1 api and queries')
    deploy("#{selfdir}app")
    start
    compile_feed_generator
    compile_query_generator
    run_stream_feeder("#{@feed_generator} 100000 1024", [])
    container = (vespa.qrserver['0'] or vespa.container.values.first)
    container.execute("#{@query_generator} 100000 0 > #{@queryfile}")
    run_fbench(container, 128, 20, [parameter_filler('tag', 'ignore'),
                                    parameter_filler('legend', 'ignore1')])
    run_fbench(container, 128, 60, [parameter_filler('tag', 'query'),
                                    parameter_filler('legend', 'getv1api')])

    container.execute("#{@query_generator} 100000 1 > #{@queryfile}")
    run_fbench(container, 128, 20, [parameter_filler('tag', 'ignore'),
                                    parameter_filler('legend', 'ignore2')])
    run_fbench(container, 128, 60, [parameter_filler('tag', 'query'),
                                    parameter_filler('legend', 'summary')])
  end
end
