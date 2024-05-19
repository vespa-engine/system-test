# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'

class StressDispatch < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    1800
  end

  def setup
    super
    set_description("Stress test dispatch merging of hits.")
    set_owner("arnej")
  end

  def test_dispatch
    app = SearchApp.new.monitoring("vespa", 60).
          sd(selfdir+"foobar.sd").
          container(Container.new("combinedcontainer").
                    jvmoptions('-Xms32g -Xmx32g').
                    search(Searching.new.
                           chain(Chain.new.add(
                                 Searcher.new("com.yahoo.example.CapInFillSearcher")).
                                 inherits("vespa"))).
                    docproc(DocumentProcessing.new).
                    documentapi(ContainerDocumentApi.new)).
          indexing("combinedcontainer").
          threads_per_search(1).
          persistence_threads(PersistenceThreads.new(8)).
          tune_searchnode({:summary => {:store => {:cache => {:maxsize => 50123000}}}}).
          config(ConfigOverride.new("vespa.config.search.core.proton").
                 add("summary", ConfigValue.new("log", ConfigValue.new("maxbucketspread", "10")))).
          num_parts(5).redundancy(1).ready_copies(1)
    add_bundle(selfdir + "CapInFillSearcher.java")
    deploy_app(app)
    clustername = @vespa.search.keys.first
    start

    profiler_start

    # feed
    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out && #{tmp_bin_dir}/a.out > feed-2.json")
    assert_equal(0, exitcode)
    (exitcode, output) = execute(node, "vespa-feed-perf < #{dirs.tmpdir}/feed-2.json")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:foobar", 12345, 30)

    profiler_report("profile_feed")
    run_benchmarks('queries.txt')
  end

  def run_benchmarks(query_file)
    clustername = vespa.search.keys.first
    # Basic search
    qrserver = @vespa.container["combinedcontainer/0"]
    legend = "simple_search"
    qrserver.copy(selfdir + query_file, dirs.tmpdir)
    queries = dirs.tmpdir + query_file
    puts "queries: #{queries}"
    just_run_fbench(qrserver, 8, 30, queries)
    run_fbench_hits(qrserver, 48, 120, queries, legend)
  end

  def just_run_fbench(qrserver, clients, runtime, queries)
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 100000
    fbench.single_query_file = true
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.query(queries)
  end

  def run_fbench_hits(qrserver, clients, runtime, queries, legend)
    append_str = "&hits=400&dispatch.summaries=false"
    run_fbench(qrserver, clients, runtime, append_str, queries, legend)
  end

  def run_fbench(qrserver, clients, runtime, append_str, queries, legend)
    custom_fillers = [parameter_filler("legend", legend)]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 100000
    fbench.single_query_file = true
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.append_str = append_str if !append_str.empty?
    fbench.ignore_first = 1000
    profiler_start
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

  def teardown
    super
  end

end
