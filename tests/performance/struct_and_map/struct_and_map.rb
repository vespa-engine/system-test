# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class StructAndMapPerf < PerformanceTest

  MAP_ATTR = 'map_attr'
  MAP_MIX = 'map_mix'

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("balder")
  end

  def get_app()
    SearchApp.new.sd(selfdir + "test.sd").
                  qrservers_jvmargs("-Xms16g -Xmx16g")
  end

  def test_matched_elements_only
    set_description("Verify performance for fetching summaries of very large maps.")
    @graphs = [
        {
            :title => 'QPS all combined',
            :x => 'legend',
            :y => 'qps',
            :historic => true
        },
        {
            :title => 'QPS matched-elements-only from attributes',
            :filter => {'legend' => MAP_ATTR},
            :x => 'legend',
            :y => 'qps',
            :historic => true
        },
        {
            :title => 'QPS matched-elements-only from summary',
            :filter => {'legend' => MAP_MIX },
            :x => 'legend',
            :y => 'qps',
            :historic => true
        },
        {
            :x => 'legend',
            :y => 'cpuutil',
            :historic => true
        }
    ]
    num_docs=10
    num_elems = 10000
    deploy_app(get_app())
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{dirs.tmpdir}/docs #{selfdir}/docs.cpp")
    start
    container.execute("#{dirs.tmpdir}/docs #{num_docs} #{num_elems}| vespa-feeder")
    assert_hitcount("sddocname:test&summary=minimal", num_docs)
    @queryfile = selfdir + 'query_map_attr.txt'
    run_fbench(container, 8, 10, [], {:append_str => "&summary=filtered_map_attr" })

    profiler_start
    run_fbench(container, 32, 30, [parameter_filler('legend', MAP_ATTR)], {:append_str => "&summary=filtered_map_attr"})
    profiler_report(MAP_ATTR)

    @queryfile = selfdir + 'query_map_mix.txt'
    profiler_start
    run_fbench(container, 32, 30, [parameter_filler('legend', MAP_MIX)], {:append_str => "&summary=filtered_map_mix"})
    profiler_report(MAP_MIX)
  end

  def teardown
    super
  end
end
