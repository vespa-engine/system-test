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

    prepare_es_app
    benchmark_feed("es_feed-1M.json.zst", 1000000)
    #benchmark_feed("es_feed-10k.json.zst", 10000)
    benchmark_query("es_queries-weak_and-10k.json", "after_feed", "weak_and")
    benchmark_query("es_queries-semantic-10k.json", "after_feed", "semantic")
    benchmark_query("es_queries-hybrid-10k.json", "after_feed", "hybrid")
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

  def benchmark_feed(feed_file, num_docs)
    files = prepare_feed_files(feed_file)
    puts "Starting to feed #{num_docs} documents among #{files.size} files..."
    system_sampler = Perf::System::new(@node)
    system_sampler.start
    start_time = Time.now
    for file in files
      @node.execute("curl -X POST '#{@es_endpoint}/_bulk?pretty&filter_path=took,errors,items.*.error' -s -H 'Content-Type: application/x-ndjson' --data-binary @#{file}")
    end
    # A refresh makes recent operations performed on one or more indices available for search.
    @node.execute("curl -X POST '#{@es_endpoint}/_refresh?pretty'")
    elapsed_sec = Time.now - start_time
    puts "Elapsed time (sec): #{elapsed_sec}"
    count_res = @node.execute("curl -X GET '#{@es_endpoint}/_count?pretty'")
    count = JSON.parse(count_res)["count"].to_i
    assert_equal(num_docs, count, "Expected #{num_docs} documents in the index, but was #{count}")
    throughput = num_docs.to_f / elapsed_sec
    puts "Throughput: #{throughput}"
    fillers = [parameter_filler("label", "feed"),
               metric_filler("feeder.throughput", throughput),
               system_metric_filler(system_sampler)]
    write_report(fillers)
  end

  def prepare_feed_files(feed_file)
    node_file = download_file(feed_file, @node)
    # This creates feed files with 6k documents each (~50 MB per file).
    feed_dir = dirs.tmpdir + "feed/"
    @node.execute("mkdir -p #{feed_dir}")
    @node.execute("zstdcat #{node_file} | split -d -a 3 -l 12000 - #{feed_dir}split_")
    files = @node.execute("cd #{feed_dir} && echo split_*").split
    files.map { |file| "#{feed_dir}#{file}" }
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
