require 'performance_test'
require 'app_generator/search_app'
require 'environment'


class NearestNeighborDistanceMetricPerfTest < PerformanceTest

  def setup
    set_owner("bergum")
  end

  def test_metrics 
    set_description('Benchmark distance 100K documents with exact nearest neighbor search using hamming and prenormalized-angular')
    deploy(selfdir + "app")
    start

    feed_file = "product-search-products.jsonl.zstd"
    remote_file = "https://data.vespa-cloud.com/sample-apps-data/#{feed_file}"
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

    c = (vespa.qrserver["0"] or vespa.container.values.first)
    t=20 # The runtime in seconds

    for clients in [1, 16] do
        query_file = selfdir + "queries_int8_64.txt"
        run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_64_hamming"), "hamming-int8-64")
        run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_64_angular"), "angular-int8-64")
        run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_64_euclidean"), "euclidean-int8-64")
        run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_64_dotproduct"), "dotproduct-int8-64") 
    end

    for clients in [1, 16] do
      query_file = selfdir + "queries_int8_128.txt"
      run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_128_hamming"), "hamming-int8-128")
      run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_128_angular"), "angular-int8-128")
      run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_128_euclidean"), "euclidean-int8-128")
      run_fbench(c, clients, t, rewrite(c,query_file, "int8_embedding_128_dotproduct"), "dotproduct-int8-128")
    end

    for clients in [1, 16] do
      query_file = selfdir + "queries_float_384.txt"
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_384_prenormalized_angular"), "prenormalized-angular-float-384")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_384_angular"), "angular-float-384")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_384_euclidean"), "euclidean-float-384")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_384_dotproduct"), "dotproduct-float-384")
    end

    for clients in [1, 16] do
      query_file = selfdir + "queries_float_512.txt"
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_512_prenormalized_angular"), "prenormalized-angular-float-512")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_512_angular"), "angular-float-512")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_512_euclidean"), "euclidean-float-512")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_512_dotproduct"), "dotproduct-float-512")
    end

    for clients in [1, 16] do
      query_file = selfdir + "queries_float_768.txt"
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_768_prenormalized_angular"), "prenormalized-angular-float-768")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_768_angular"), "angular-float-768")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_768_euclidean"), "euclidean-float-768")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_768_dotproduct"), "dotproduct-float-768")
    end

    for clients in [1, 16] do
      query_file = selfdir + "queries_float_1024.txt"
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_1024_prenormalized_angular"), "prenormalized-angular-float-1024")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_1024_angular"), "angular-float-1024")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_1024_euclidean"), "euclidean-float-1024")
      run_fbench(c, clients, t, rewrite(c,query_file, "float_embedding_1024_dotproduct"), "dotproduct-float-1024")
    end
  end

  def rewrite(c, file, tensor_field_name)
    # Read the file and replace FIELD_NAME wih field and return the new file
    lines = File.readlines(file)
    lines.each do |line|
        line.gsub!("FIELD_NAME", tensor_field_name)
    end

    query_file = "#{tensor_field_name}.txt"
    query_directory = dirs.tmpdir + "qd"
    remote_file = query_directory + "/" + File.basename(query_file)
    File.open(query_file, "w") { |f| f.puts lines }
    c.copy(query_file, query_directory)
    return remote_file
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
    fbench.append_str = "&ranking.profile=#{legend}&timeout=5s"
    profiler_start
    fbench.query(queries)
    system_fbench.end
    profiler_report(legend)
    fillers = [fbench.fill, system_fbench.fill]
    write_report(fillers + custom_fillers)
  end
end
