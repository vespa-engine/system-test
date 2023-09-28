require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class ColBertEmbeddingPerfTest < PerformanceTest

  def setup
    set_owner("bergum")
  end

  def test_colbert
    set_description('Benchmark feed and query throughput with ColBERT end2end or just max sim')
    deploy(selfdir + "app")
    start

    feed_file = "product-search-products.jsonl.zstd"
    remote_file = "https://data.vespa.oath.cloud/sample-apps-data/#{feed_file}"
    local_file =  dirs.tmpdir + feed_file
    local_feed_file =  dirs.tmpdir + "feed.json"
    cmd = "wget -O'#{local_file}' '#{remote_file}'"
    puts "Running command #{cmd}"
    result = `#{cmd}`

    #Feed max 100K docs
    script = selfdir + "export.py"
    puts "Result: #{result}"
    cmd2 = "zstdcat '#{local_file}' | head -100000 | python3 '#{script}' > '#{local_feed_file}'"
    puts "Running command #{cmd2}"
    result2 = `#{cmd2}`
    puts "Result2: #{result2}"
    run_feeder(local_feed_file, [])

    container = (vespa.qrserver["0"] or vespa.container.values.first)
    runtime=30
    for clients in [1, 2, 16] do
        run_fbench(container, clients, runtime, get_query("max-sim-default"), selfdir + "queries.txt", "end2end", false)
    end

    for clients in [1, 2, 16, 32] do
         run_fbench(container, clients, runtime, get_query("max-sim-default"), selfdir + "queries_post.txt", "max_sim", true)
    end

  end

  def get_query(rank_profile)
      "&ranking.profile=#{rank_profile}&timeout=5s"
  end

  def run_fbench(qrserver, clients, runtime, append_str, queries, legend, post)
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
    fbench.append_str = append_str if !append_str.empty?
    profiler_start
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end
end
