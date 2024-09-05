# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class NearestNeighborDistanceMetricAndTypesPerfTest < PerformanceTest

  def setup
    set_owner("bergum")
  end

  def test_metrics_and_types
    set_description('Benchmark distance metrics and cell types using 100K documents. Exact nearest neighbor search.')
    deploy_app(SearchApp.new.sd(selfdir + 'vector.sd'))
    start
  
    remote_file = "https://data.vespa-cloud.com/tests/performance/vectors.100k.perf.json.zst"
    cmd = "curl -s '#{remote_file}' | zstdcat"
    run_stream_feeder(cmd, [])

    container = (vespa.qrserver["0"] or vespa.container.values.first)
    runtime=20 # The runtime in seconds
    test_container_query_directory = dirs.tmpdir + "qd"
    # float vectors of various sizes x metrics
    for client in [1, 16] do
      for dimension in [256, 384, 512, 768, 1024] do
        for metric in ["prenormalized_angular", "angular", "euclidean", "dotproduct"] do
          query_file = selfdir + "queries/float-#{dimension}-#{metric}.txt"
          container.copy(query_file, test_container_query_directory)
          remote_file = test_container_query_directory + "/" + File.basename(query_file)
          run_fbench(container, client, runtime, remote_file, "float-#{metric}-#{dimension}")
        end
      end
    end
      # int8 vectors of various sizes x metrics (scalar quantization from float to int8)
    for client in [1, 16] do
      for dimension in [256, 384, 512, 768, 1024] do
        for metric in ["angular", "euclidean", "dotproduct"] do
          query_file = selfdir + "queries/scalar-int8-#{dimension}-#{metric}.txt"
          container.copy(query_file, test_container_query_directory)
          remote_file = test_container_query_directory + "/" + File.basename(query_file)
          run_fbench(container, client, runtime, remote_file, "scalar-int8-#{metric}-#{dimension}")
        end
      end
    end
    # Binary int8 vectors of various sizes x hamming distance 
    for client in [1, 16] do
      for dimension in [64, 96, 128] do
        metric = "hamming"
        query_file = selfdir + "queries/binary-int8-#{dimension}-#{metric}.txt"
        container.copy(query_file, test_container_query_directory)
        remote_file = test_container_query_directory + "/" + File.basename(query_file)
        run_fbench(container, client, runtime, remote_file, "binary-int8-#{metric}-#{dimension}")
      end
    end

    # Different number of threads per search
    client = 1
    dimension = 128
    metric = "hamming"
    query_file = selfdir + "queries/binary-int8-#{dimension}-#{metric}.txt"
    remote_file = test_container_query_directory + "/" + File.basename(query_file)
    for threads in [1, 2, 4] do  
      run_fbench(container, client, runtime, remote_file, "binary-int8-#{metric}-#{dimension}-threads-#{threads}", threads)
    end
  end

  def run_fbench(qrserver, clients, runtime, queries, legend, threads=4, post=true)
    custom_fillers = [parameter_filler("legend", legend)]
    system_fbench = Perf::System.new(qrserver)
    system_fbench.start
    fbench = Perf::Fbench.new(qrserver, qrserver.name, qrserver.http_port)
    fbench.max_line_size = 100000
    fbench.runtime = runtime
    fbench.clients = clients
    if post
        fbench.use_post = true
    end
    fbench.append_str = "&ranking.matching.numThreadsPerSearch=#{threads}&timeout=5s"
    profiler_start
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end
end
