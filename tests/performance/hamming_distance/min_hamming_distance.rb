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
    deploy_app(SearchApp.new.sd(selfdir + 'hamming.sd').search_dir(selfdir + 'search'))
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
    res = search('/search/?query=title:doc&ranking.features.query(qvector)=%7B%7Bquestion:n0,x:0%7D:101,%7Bquestion:n0,x:1%7D:41,%7Bquestion:n0,x:2%7D:-127,%7Bquestion:n0,x:3%7D:96,%7Bquestion:n0,x:4%7D:118,%7Bquestion:n0,x:5%7D:124,%7Bquestion:n0,x:6%7D:-99,%7Bquestion:n0,x:7%7D:15,%7Bquestion:n0,x:8%7D:66,%7Bquestion:n0,x:9%7D:-112,%7Bquestion:n0,x:10%7D:-12,%7Bquestion:n0,x:11%7D:-62,%7Bquestion:n0,x:12%7D:86,%7Bquestion:n0,x:13%7D:44,%7Bquestion:n0,x:14%7D:16,%7Bquestion:n0,x:15%7D:-68,%7Bquestion:n1,x:0%7D:50,%7Bquestion:n1,x:1%7D:84,%7Bquestion:n1,x:2%7D:-39,%7Bquestion:n1,x:3%7D:33,%7Bquestion:n1,x:4%7D:44,%7Bquestion:n1,x:5%7D:88,%7Bquestion:n1,x:6%7D:-103,%7Bquestion:n1,x:7%7D:-17,%7Bquestion:n1,x:8%7D:-86,%7Bquestion:n1,x:9%7D:125,%7Bquestion:n1,x:10%7D:-103,%7Bquestion:n1,x:11%7D:-84,%7Bquestion:n1,x:12%7D:-1,%7Bquestion:n1,x:13%7D:-36,%7Bquestion:n1,x:14%7D:53,%7Bquestion:n1,x:15%7D:101,%7Bquestion:n2,x:0%7D:5,%7Bquestion:n2,x:1%7D:-74,%7Bquestion:n2,x:2%7D:-59,%7Bquestion:n2,x:3%7D:123,%7Bquestion:n2,x:4%7D:50,%7Bquestion:n2,x:5%7D:98,%7Bquestion:n2,x:6%7D:-118,%7Bquestion:n2,x:7%7D:116,%7Bquestion:n2,x:8%7D:-14,%7Bquestion:n2,x:9%7D:127,%7Bquestion:n2,x:10%7D:54,%7Bquestion:n2,x:11%7D:72,%7Bquestion:n2,x:12%7D:-85,%7Bquestion:n2,x:13%7D:71,%7Bquestion:n2,x:14%7D:4,%7Bquestion:n2,x:15%7D:-35,%7Bquestion:n3,x:0%7D:-101,%7Bquestion:n3,x:1%7D:-34,%7Bquestion:n3,x:2%7D:-2,%7Bquestion:n3,x:3%7D:-57,%7Bquestion:n3,x:4%7D:54,%7Bquestion:n3,x:5%7D:-105,%7Bquestion:n3,x:6%7D:-73,%7Bquestion:n3,x:7%7D:-32,%7Bquestion:n3,x:8%7D:20,%7Bquestion:n3,x:9%7D:80,%7Bquestion:n3,x:10%7D:-115,%7Bquestion:n3,x:11%7D:20,%7Bquestion:n3,x:12%7D:45,%7Bquestion:n3,x:13%7D:-62,%7Bquestion:n3,x:14%7D:121,%7Bquestion:n3,x:15%7D:50%7D')
    puts res.xmldata

    run_benchmarks(qf1, 'best_hamming_distances')
  end

  def in_tmp(name)
    dirs.tmpdir + name
  end

  def run_benchmarks(query_file, legend)
    node = (vespa.qrserver["0"] or vespa.container.values.first)
    tmp_query_dir = in_tmp('qd')
    node.copy(query_file, tmp_query_dir)
    qf = tmp_query_dir + '/' + File.basename(query_file)
    puts "qf: #{qf}"
    run_fbench(node, 48, 20, qf, legend)
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
