# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'environment'

class DispatchMerge < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("balder")
  end

  def get_app()
    SearchApp.new.sd(selfdir + "test.sd").
                  search_dir(selfdir + "app").
                  qrservers_jvmargs("-Xms16g -Xmx16g").
                  elastic.num_parts(8).redundancy(1).ready_copies(1)
  end

  def test_merge
    set_description("Test merge speed with 8 backend and large offsets.")
    @graphs = [
      {
        :title => "Qps",
        :x => 'legend',
        :y => 'qps',
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
    num_docs = 400000
    deploy_app(get_app())
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{dirs.tmpdir}/docs #{selfdir}/docs.cpp")
    start
    container.execute("#{dirs.tmpdir}/docs #{num_docs} | vespa-feeder")
    assert_hitcount("sddocname:test", num_docs)

    result = search("/search/?query=sddocname:test&ranking=score&hits=10&offset=300&format=json").json
    puts "Result Query #1: " + JSON.pretty_generate(result)

    @queryfile = selfdir + 'query.txt'
    run_fbench(container, 8, 20, [], {:append_str => "&hits=10&offset=1000" })
    run_fbench(container, 8, 20, [], {:append_str => "&hits=10&offset=1000&dispatch.internal" })

    [125, 1000, 8000, 32000].each do |offset|
        profiler_start
        run_fbench(container, 8, 30, [parameter_filler('legend', "test_fdispatch_#{offset}"),
                   metric_filler('memory.rss', container.memusage_rss(container.get_pid))], {:append_str => "&ranking=score&hits=10&offset=#{offset}&timeout=50.0" })

        profiler_report("test_fdispatch_#{offset}")
        profiler_start
        run_fbench(container, 8, 30, [parameter_filler('legend', "test_java_dispatch_#{offset}"),
                   metric_filler('memory.rss', container.memusage_rss(container.get_pid))], {:append_str => "&ranking=score&hits=10&offset=#{offset}&dispatch.internal&timeout=50.0" })
        profiler_report("test_java_dispatch_#{offset}")
    end
  end

  def teardown
    super
  end

end
