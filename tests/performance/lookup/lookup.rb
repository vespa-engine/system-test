# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'environment'

class LookupPerformance < PerformanceTest

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
                  container(Container.new("combinedcontainer").
                                      jvmoptions("-Xms16g -Xmx16g").
                                      search(Searching.new).
                                      docproc(DocumentProcessing.new).
                                      documentapi(ContainerDocumentApi.new).
                                      component(AccessLog.new("disabled"))).
                  indexing("combinedcontainer")
  end

  def test_dictionary_lookup
    set_description("Test lookupspeed with btree vs hash.")
    num_docs = 10000000
    num_values_per_doc=10
    upper_limit = num_docs*num_values_per_doc*10
    keys_per_query = 100
    num_clients = 40
    num_queries = num_clients * 40000
    deploy_app(get_app())
    container = (vespa.qrserver["0"] or vespa.container.values.first)
    tmp_bin_dir = container.create_tmp_bin_dir
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{tmp_bin_dir}/docs #{selfdir}/docs.cpp")
    container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{tmp_bin_dir}/query #{selfdir}/query.cpp")
    start
    container.execute("#{tmp_bin_dir}/docs #{num_docs} #{num_values_per_doc} | vespa-feeder")
    assert_hitcount("sddocname:test", num_docs)

    @queryfile = "#{dirs.tmpdir}/query.txt"
    container.execute("#{tmp_bin_dir}/query #{num_queries} #{keys_per_query} #{upper_limit} > #{@queryfile}")
    run_fbench(container, 8, 20)
    restart_proton("test", num_docs)

    ["f1", "f1_hash", "s1", "s1_cased", "s1_hash"].each do |field|
        profiler_start
        run_fbench(container, num_clients, 60, [parameter_filler('legend', "lookup_#{field}")],
                   {:single_query_file => true, :append_str => "&hits=1&summary=minimal&ranking=unranked&wand.type=dotProduct&wand.field=#{field}"})
        profiler_report("lookup_#{field}")
    end
  end

  def teardown
    super
  end

end
