# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class StructAndMapPerf < PerformanceTest

  MAP_ATTR = 'map_attr'
  MAP_MIX = 'map_mix'
  NUM_CLIENTS = 32

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("balder")
  end

  def get_app()
    SearchApp.new.sd(selfdir + "test.sd").
                  threads_per_search(1).
                  num_summary_threads(NUM_CLIENTS).
                  container(Container.new.search(Searching.new).
                  jvmoptions("-Xms16g -Xmx16g"))
  end

  def test_matched_elements_only
    set_description("Verify performance for fetching summaries of very large maps.")
    num_docs=10
    num_elems = 10000
    deploy_app(get_app())
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    tmp_bin_dir = container.create_tmp_bin_dir
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{tmp_bin_dir}/docs #{selfdir}/docs.cpp")
    start
    container.execute("#{tmp_bin_dir}/docs #{num_docs} #{num_elems}| vespa-feeder")
    assert_hitcount("sddocname:test&summary=minimal", num_docs)
    @queryfile = selfdir + 'query_map_attr.txt'
    run_fbench(container, 8, 10, [], {:append_str => "&summary=filtered_map_attr&language=en" })

    profiler_start
    run_fbench(container, NUM_CLIENTS, 30, [parameter_filler('legend', MAP_ATTR)], {:append_str => "&summary=filtered_map_attr&language=en"})
    profiler_report(MAP_ATTR)

    @queryfile = selfdir + 'query_map_mix.txt'
    profiler_start
    run_fbench(container, NUM_CLIENTS, 30, [parameter_filler('legend', MAP_MIX)], {:append_str => "&summary=filtered_map_mix&language=en"})
    profiler_report(MAP_MIX)
  end

  def teardown
    super
  end
end
