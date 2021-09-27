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
    puts "GENERATING QUERIES"
    qf1 = in_tmp('hamming-queries.txt')
    write_hamming_queries(qf1)
    puts "DONE QUERY GENERATING"
    puts "FEEDING DOCUMENTS"
    node = vespa.adminserver
    node.copy(selfdir + "gendata.c", dirs.tmpdir)
    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && gcc gendata.c -o #{tmp_bin_dir}/a.out")
    assert_equal(0, exitcode)
    (exitcode, output) = execute(node, "#{tmp_bin_dir}/a.out | vespa-feeder")
    assert_equal(0, exitcode)
    wait_for_hitcount("sddocname:hamming", 10000, 30)
    puts "DONE FEEDING"
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

  def write_hamming_queries(qfn)
    File.open(qfn, 'w') do |f|
      (1..99999).each do |num|
        byteval = (num % 256) - 128
        v = "[#{byteval}"
        v += ",#{byteval}" * 63
        v += ']'
        f.puts("/search/?query=title:doc&ranking.features.query(qvector)=#{v}")
      end
    end
  end

  def teardown
    stop
  end

end
