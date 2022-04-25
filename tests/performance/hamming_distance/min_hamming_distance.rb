# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class MinHammingDistancePerfTest <  PerformanceTest

  def setup
    set_owner('arnej')
  end

  def test_min_hamming_distance_perf
    set_description('Test performance of minimum hamming distance')
    deploy_app(SearchApp.new.sd(selfdir + 'hamming.sd'))
    start
    puts "COMPILE GENERATOR"
    node = vespa.adminserver
    node.copy(selfdir + 'gendata.c', dirs.tmpdir)
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c")
    assert_equal(0, exitcode)
    puts "GENERATING QUERIES"
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && ./a.out queries > hamming-queries.txt")
    assert_equal(0, exitcode)
    qf1 = in_tmp('hamming-queries.txt')
    puts "DONE QUERY GENERATING"
    puts "FEEDING DOCUMENTS"
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && ./a.out docs | vespa-feeder")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:hamming", 10000, 30)
    puts "DONE FEEDING"
    puts "SMOKE TEST"
    smoke_test
    puts "DONE SMOKE TEST"
    run_benchmarks(qf1, 'best_hamming_distances')
  end

  def in_tmp(name)
    dirs.tmpdir + name
  end

  def smoke_test
    query = '/search/?query=title:doc&ranking.features.query(qvector)=%7B'
    vectors = [ 
               [  101,   41,  -127,   96,  118,   124,   -99,   15,   66,  -112,   -12,  -62,   86,   44,   16,  -68 ],
               [   50,   84,   -39,   33,   44,    88,  -103,  -17,  -86,   125,  -103,  -84,   -1,  -36,   53,  101 ],
               [    5,  -74,   -59,  123,   50,    98,  -118,  116,  -14,   127,    54,   72,  -85,   71,    4,  -35 ],
               [ -101,  -34,    -2,  -57,   54,  -105,   -73,  -32,   20,    80,  -115,   20,   45,  -62,  121,   50 ]
              ]
    vectors.each_index do |qnum|
      vector = vectors[qnum]
      vector.each_index do |x|
        value = vector[x]
        query += ',' if (qnum + x > 0)
        query += '%7B' + "question:n#{qnum},x:#{x}" + '%7D:' + value.to_s
      end
    end
    query += '%7D&ranking.profile=debugging'
    res = search(query)
    puts res.xmldata
  end

  def run_benchmarks(query_file, legend)
    node = (vespa.qrserver["0"] or vespa.container.values.first)
    puts "qf: #{query_file}"
    run_fbench(node, 48, 20, query_file, legend)
  end                    

  def run_fbench(qrserver, clients, runtime, qf, legend, append_str = nil)
    custom_fillers = [
      parameter_filler("legend", legend),
    ]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 10000
    fbench.single_query_file = true
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.append_str = append_str if append_str
    fbench.ignore_first = 10
    profiler_start
    fbench.query(qf)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end

  def teardown
    stop
  end

end
