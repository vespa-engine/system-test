# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class PhraseCasesPerformanceTest < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    1800
  end

  def setup
    set_description('Test various cases with phrase search')
    set_owner("arnej")
  end

  def file_in_tmp(file_name)
    dirs.tmpdir + file_name
  end

  def write_queries(query, qfn)
    File.open(qfn, 'w') do |f|
      (1..99999).each do |num|
        f.puts("/search/?query=phrases:#{query}+whitelist:50+-title:#{num}")
      end
    end
  end


  def test_phrase_cases

    app = SearchApp.new.monitoring("vespa", 60).
          sd(selfdir+"foobar.sd").
          container(Container.new("combinedcontainer").
                    search(Searching.new).
                    docproc(DocumentProcessing.new).
                    gateway(ContainerDocumentApi.new)).
          indexing("combinedcontainer").
          threads_per_search(1)
    deploy_app(app)
    @graphs = get_graphs()
    start

    # queries
    qf1 = file_in_tmp('bestcase-queries.txt')
    write_queries('ten.twenty', qf1)
    qf2 = file_in_tmp('worstcase-queries.txt')
    write_queries('worst.case', qf2)

    # feed
    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c && ./a.out > feed-phrases.xml")
    assert_equal(0, exitcode)
    (exitcode, output) = execute(node, "vespa-feed-perf < #{dirs.tmpdir}/feed-phrases.xml")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:foobar", 123456, 30)

    run_benchmarks(qf1, 'bestcase')
    run_benchmarks(qf2, 'worstcase')
  end

  def run_benchmarks(query_file, legend)
    # Basic search
    qrserver = @vespa.container["combinedcontainer/0"]
    qd = dirs.tmpdir + "qd"
    qrserver.copy(query_file, qd)
    qf = qd + "/" + File.basename(query_file)
    puts "qf: #{qf}"
    run_fbench(qrserver, 48, 120, qf, legend)
  end

  def run_fbench(qrserver, clients, runtime, qf, legend)
    custom_fillers = [parameter_filler("legend", legend)]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 10000
    fbench.single_query_file = true
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.ignore_first = 1000
    profiler_start
    fbench.query(qf)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

  def get_graphs()
    local_graphs = [
      {
        :x => 'legend',
        :y => 'qps',
        :title => 'phrase_bestcase_qps',
        :y_min => 1,
        :y_max => 1000000,
        :filter => {'legend' => "bestcase"},
        :historic => true
      },
      {
        :x => 'legend',
        :y => 'qps',
        :title => 'phrase_worstcase_qps',
        :y_min => 1,
        :y_max => 1000000,
        :filter => {'legend' => "worstcase"},
        :historic => true
      }
    ]
    return local_graphs
  end

  def teardown
    stop
  end

end
