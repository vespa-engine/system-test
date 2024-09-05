# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class MixedTensorMaxSim < PerformanceTest

  def setup
    set_owner("bergum")
  end

  def test_max_sim_performance_1d
    set_description('Benchmark single-thred MaxSim performance with one mapped dimension and one indexed dimension. 
    Using different precision types and similarity functions.')
    deploy_app(SearchApp.new.sd(selfdir + 'page.sd'))
    start

    remote_file = "https://data.vespa-cloud.com/tests/performance/max-sim-colpali-vectors.json.zst"
    cmd = "curl -s '#{remote_file}' | zstdcat"
    #can also use local file 
    #cmd = " cat #{selfdir}max-sim-colpali-vectors.json.zst | zstdcat"
    
    run_stream_feeder(cmd, [])

    container = (vespa.qrserver["0"] or vespa.container.values.first)
    runtime=20
    test_container_query_directory = dirs.tmpdir + "qd"
    
    for client in [1] do
      for test in ["float-float-dotproduct", "float-float-dotproduct-random", "float-unpacked-bits-dotproduct", "bits-bits-hamming"] do
        query_file = selfdir + "queries/#{test}.txt"
        container.copy(query_file, test_container_query_directory)
        remote_file = test_container_query_directory + "/" + File.basename(query_file)
        run_fbench(container, client, 10, remote_file, test, warmup=true)
        run_fbench(container, client, runtime, remote_file, test)
      end
    end
  end


  def run_fbench(qrserver, clients, runtime, queries, legend, warmup=false)
    custom_fillers = [parameter_filler("legend", legend)]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 100000
    fbench.runtime = runtime
    fbench.clients = clients
    fbench.use_post = true
    fbench.append_str = "&timeout=10s"
    profiler_start if !warmup
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend) if !warmup 
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers) if !warmup
  end
end
