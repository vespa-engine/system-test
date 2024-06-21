# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require_relative 'ecommerce_hybrid_search_base'
require 'json'

class EcommerceHybridSearchESTest < EcommerceHybridSearchTestBase

  def setup
    super
    set_owner("geirst")
  end

  def test_hybrid_search
    set_description("Test performance of hybrid search on ES using an E-commerce dataset (feeding, queries, re-feeding with queries)")
    @node = vespa.nodeproxies.values.first
    @es_version = "8.13.4"
    @es_hostname = "localhost"
    @es_port = 9200
    @es_endpoint = "http://#{@es_hostname}:#{@es_port}"
    @minimal = false
    prepare_es_app
    @feed_threads = 16

    benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "feed")
    benchmark_queries("after_feed", true)
    feed_thread = Thread.new { benchmark_feed(feed_file_name, get_num_docs, @feed_threads, "refeed") }
    sleep 5
    benchmark_queries("during_refeed", false)
    feed_thread.join
    benchmark_update("es_update-1M.json.zst", get_num_docs, @feed_threads)
  end

  def feed_file_name
    @minimal ? "es_feed-10k.json.zst" : "es_feed-1M.json.zst"
  end

  def get_num_docs
    @minimal ? 10000 : 1000000
  end

  def prepare_es_app
    install_es
    start_es
    create_index
  end

  def install_es
    arch = @node.execute("arch").strip
    puts "Running on architecture: #{arch}"
    package_file = "elasticsearch-#{@es_version}-linux-#{arch}.tar.gz"
    node_file = download_file(package_file, @node, "https://artifacts.elastic.co/downloads/elasticsearch")
    @node.execute("tar -xzf #{node_file} --directory #{dirs.tmpdir}")
    @es_dir = dirs.tmpdir + "elasticsearch-#{@es_version}"
  end

  def start_es
    @es_pidfile = @es_dir + "/es_pid"
    cmd = "#{@es_dir}/bin/elasticsearch -E \"discovery.type=single-node\" -E \"xpack.security.enabled=false\" -E \"xpack.security.http.ssl.enabled=false\" -d -p #{@es_pidfile}"
    if @node.execute("id -u").to_i == 0
      # ES cannot be executed as root. Run as the vespa user instead.
      vespa_user = Environment.instance.vespa_user
      @node.execute("chown -R #{vespa_user}:#{vespa_user} #{@es_dir}")
      @node.execute("sudo -u #{vespa_user} #{cmd}")
    else
      @node.execute(cmd)
    end
  end

  def stop_es
    @node.execute("test -f #{@es_pidfile} && pkill -F #{@es_pidfile} || true")
  end

  def create_index
    @node.copy(selfdir + "app_es/index-settings.json", dirs.tmpdir)
    node_file = dirs.tmpdir + "index-settings.json"
    @node.execute("curl -X PUT '#{@es_endpoint}/product?pretty' -H 'Content-Type: application/json' -d @#{node_file}")
  end

  def benchmark_feed(feed_file, num_docs, num_threads, label)
    # This creates feed files with 6k documents each (~50 MB per file).
    files = prepare_feed_files(feed_file, dirs.tmpdir + "feed/", 12000)
    benchmark_feed_helper(files, num_docs, num_threads, label)
  end

  def benchmark_update(update_file, num_docs, num_threads)
    # This creates update files with 6k documents each (~0.4 MB per file).
    files = prepare_feed_files(update_file, dirs.tmpdir + "update/", 12000)
    benchmark_feed_helper(files, num_docs, num_threads, "update")
  end

  def benchmark_feed_helper(files, num_docs, num_threads, label)
    files_per_thread = (files.size.to_f / num_threads.to_f).ceil
    puts "Starting to #{label} #{num_docs} documents: files=#{files.size}, threads=#{num_threads}, files_per_thread=#{files_per_thread}"
    system_sampler = Perf::System::new(@node)
    system_sampler.start
    profiler_start
    start_time = Time.now
    threads = []
    files.each_slice(files_per_thread) do |slice|
      t = Thread.new do
        puts "Starting thread #{Thread.current.object_id} to feed #{slice.size} files..."
        for file in slice
          @node.execute("curl -X POST '#{@es_endpoint}/_bulk?pretty&filter_path=took,errors,items.*.error' -s -H 'Content-Type: application/x-ndjson' --data-binary @#{file}")
        end
      end
      threads.push(t)
    end
    for t in threads
      t.join
    end
    # A refresh makes recent operations performed on one or more indices available for search.
    @node.execute("curl -X POST '#{@es_endpoint}/_refresh?pretty'")
    elapsed_sec = Time.now - start_time
    profiler_report(label)
    puts "Elapsed time (sec): #{elapsed_sec}"
    count_res = @node.execute("curl -X GET '#{@es_endpoint}/_count?pretty'")
    count = JSON.parse(count_res)["count"].to_i
    assert_equal(num_docs, count, "Expected #{num_docs} documents in the index, but was #{count}")
    throughput = num_docs.to_f / elapsed_sec
    puts "Throughput: #{throughput}"
    fillers = [parameter_filler("label", label),
               metric_filler("feeder.throughput", throughput),
               system_metric_filler(system_sampler)]
    write_report(fillers)
  end

  def prepare_feed_files(feed_file, feed_dir, lines_per_file)
    node_file = download_file(feed_file, @node)
    @node.execute("mkdir -p #{feed_dir}")
    @node.execute("zstdcat #{node_file} | split -d -a 3 -l #{lines_per_file} - #{feed_dir}split_")
    files = @node.execute("cd #{feed_dir} && echo split_*").split
    files.map { |file| "#{feed_dir}#{file}" }
  end

  def benchmark_queries(query_phase, run_filter_queries)
    benchmark_query("es_queries-weak_and-10k.json", query_phase, "weak_and")
    benchmark_query("es_queries-semantic-10k.json", query_phase, "semantic")
    benchmark_query("es_queries-hybrid-10k.json", query_phase, "hybrid")
    if run_filter_queries
      benchmark_query("es_queries-weak_and-filter-10k.json", query_phase, "weak_and_filter")
      benchmark_query("es_queries-semantic-filter-10k.json", query_phase, "semantic_filter")
      benchmark_query("es_queries-hybrid-filter-10k.json", query_phase, "hybrid_filter")
    end
  end

  def benchmark_query(query_file, query_phase, query_type)
    run_fbench_helper(query_file, query_phase, query_type, @node,
                      {:port_override => @es_port,
                       :hostname_override => @es_hostname,
                       :disable_tls => true})
  end

  def teardown
    stop_es
    super
  end

end
