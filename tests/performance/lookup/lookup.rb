# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'environment'

class Lookup < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("balder")
  end

  def get_app()
    SearchApp.new.sd(selfdir + "test.sd").
                  qrservers_jvmargs("-Xms4g -Xmx4g")
  end

  def test_dictionary_lookup
    set_description("Test lookupspeed with btree vs hash.")
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
    num_docs = 1000000
    num_queries = num_docs
    upper_limit = num_docs*10
    keys_per_query = 100
    num_clients = 16
    deploy_app(get_app())
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{dirs.tmpdir}/docs #{selfdir}/docs.cpp")
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{dirs.tmpdir}/query #{selfdir}/query.cpp")
    start
    container.execute("#{dirs.tmpdir}/docs #{num_docs} | vespa-feeder")
    container.execute("#{dirs.tmpdir}/query #{num_queries} #{keys_per_query} #{upper_limit} f1 > #{dirs.tmpdir}/query.txt")
    assert_hitcount("sddocname:test", num_docs)

    @queryfile = "#{dirs.tmpdir}/query.txt"
    run_fbench(container, 8, 20)

    ["f1", "f1_hash"].each do |field|
        container.execute("#{dirs.tmpdir}/query #{num_queries} #{keys_per_query} #{upper_limit} #{field} > #{@queryfile}")
        profiler_start
        run_fbench(container, num_clients, 30, [parameter_filler('legend', "lookup_#{field}")])
        profiler_report("lookup_#{field}")
    end
  end

  def teardown
    super
  end

end
