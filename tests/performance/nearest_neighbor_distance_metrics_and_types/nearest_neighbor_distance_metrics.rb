require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class NearestNeighborDistanceMetricAndTypesPerfTest < PerformanceTest

  def setup
    set_owner("bergum")
  end

  def test_metrics_and_types
    set_description('Benchmark distance metrics and types using 500K documents. Exact nearest neighbor search.')
    deploy_app(SearchApp.new.sd(selfdir + 'vector.sd'))
    start
  
    feed_file = 'vectors.perf.json.zstd'
    remote_file = "https://data.vespa.oath.cloud/tests/performance/#{feed_file}"
    local_file =  dirs.tmpdir + feed_file
    local_feed_file =  dirs.tmpdir + "feed.json"
    cmd = "wget -O'#{local_file}' '#{remote_file}'"
    puts "Running command #{cmd}"
    result = `#{cmd}`
    puts "Result: #{result}"

    cmd2 = "zstdcat '#{local_file}' > '#{local_feed_file}'"
    puts "Running command #{cmd2}"
    result2 = `#{cmd2}`
    puts "Result2: #{result2}"
    run_feeder(local_feed_file, [])

    container = (vespa.qrserver["0"] or vespa.container.values.first)
    runtime=20 # The runtime in seconds
    test_container_query_directory = dirs.tmpdir + "qd"
    for client in [1, 16] do
      for dimension in [256, 384, 768, 1024] do
        for metric in ["prenormalized_angular", "angular", "euclidean", "dotproduct"] do
          query_file = selfdir + "queries/float-#{dimension}-#{metric}.txt"
          container.copy(query_file, test_container_query_directory)
          remote_file = test_container_query_directory + "/" + File.basename(query_file)
          run_fbench(container, client, runtime, remote_file, "float-#{metric}-#{dimension}")
        end
      end
    end

    for client in [1,16] do
      for dimension in [256, 384, 768, 1024] do
        for metric in ["angular", "euclidean", "dotproduct"] do
          query_file = selfdir + "queries/scalar-int8-#{dimension}-#{metric}.txt"
          container.copy(query_file, test_container_query_directory)
          remote_file = test_container_query_directory + "/" + File.basename(query_file)
          run_fbench(container, client, runtime, remote_file, "scalar-int8-#{metric}-#{dimension}")
        end
      end
    end

    for client in [1,16] do
      for dimension in [64, 96, 128] do
        metric = "hamming"
        query_file = selfdir + "queries/binary-int8-#{dimension}-#{metric}.txt"
        container.copy(query_file, test_container_query_directory)
        remote_file = test_container_query_directory + "/" + File.basename(query_file)
        run_fbench(container, client, runtime, remote_file, "binary-int8-#{metric}-#{dimension}")
      end
    end
  end

  def run_fbench(qrserver, clients, runtime, queries, legend, post=true)
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
    profiler_start
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end
end
