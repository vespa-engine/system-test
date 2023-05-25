# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'uri'

class NearestNeighborStreamingTest < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def test_nearest_neighbor_streaming_mode
    set_description("Test query performance of the nearestNeighbor query operator in streaming mode")
    deploy_app(create_app)
    @container = vespa.container.values.first
    compile_create_docs
    batches = 5
    write_query_files(batches)
    start

    feed_and_profile(batches)
    run_query_and_profile
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      streaming().
      container(Container.new("combinedcontainer").
                jvmoptions('-Xms8g -Xmx8g').
                search(Searching.new).
                docproc(DocumentProcessing.new).
                documentapi(ContainerDocumentApi.new)).
      tune_searchnode({:summary => {:io => {:read => "directio"} } })
    # We use the same summary io read setting as in Vespa Cloud (default is mmap),
    # to avoid using the disk buffer cache of the OS.
    
    # The document store cache is default enabled, meaning that documents are eventually
    # served from the cache when running queries.
    # If the cache is disabled we instead end up benchmarking the disk read performance.
    # tune_searchnode({:summary => {:store => {:cache => {:maxsize => 0} } } })
  end

  def compile_create_docs
    tmp_bin_dir = @container.create_tmp_bin_dir
    @create_docs = "#{tmp_bin_dir}/create_docs"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@create_docs} #{selfdir}/create_docs.cpp")
  end

  def feed_and_profile(batches)
    # We feed batches of 500k documents, where each batch has:
    #   - 100k docs with 10000 users with 10 docs each
    #   - 100k docs with 1000 users with 100 docs each
    #   - 100k docs with 100 users with 1k docs each
    #   - 100k docs with 10 users with 10k docs each
    #   - 100k docs with 1 user with 100k docs each
    command = "#{@create_docs} #{batches} 384"
    profiler_start
    run_stream_feeder(command, [parameter_filler("type", "feed")])
    profiler_report("feed")
  end

  def random_vector(count)
    res = []
    count.times do
      res << rand(0...10000) / 10000.0
    end
    res.to_s
  end

  def get_query(user_id)
    "/search/?" + URI.encode_www_form("yql" => "select * from sources * where {targetHits:10}nearestNeighbor(embedding,qemb)",
                                      "input.query(qemb)" => random_vector(384),
                                      "streaming.selection" => "id.user=#{user_id}",
                                      "presentation.summary" => "minimal",
                                      "hits" => "10")
  end

  def write_queries(file_name, num_users, start_id)
    File.open(file_name, 'w') do |f|
      (0...num_users).each do |id|
        f.puts(get_query(start_id + id))
      end
    end
  end

  def write_query_files(batches)
    @qf10 = dirs.tmpdir + "queries.10.dpu.txt"
    @qf100 = dirs.tmpdir + "queries.100.dpu.txt"
    @qf1k = dirs.tmpdir + "queries.1k.dpu.txt"
    @qf10k = dirs.tmpdir + "queries.10k.dpu.txt"
    @qf100k = dirs.tmpdir + "queries.100k.dpu.txt"
    # Must match the same id range used in create_docs.cpp
    id_range = 10000000;
    write_queries(@qf10, 5000, id_range)
    write_queries(@qf100, 1000 * batches, id_range * 2)
    write_queries(@qf1k, 100 * batches, id_range * 3)
    write_queries(@qf10k, 10 * batches, id_range * 4)
    write_queries(@qf100k, 1 * batches, id_range * 5)
  end

  def run_query_and_profile
    query_and_profile(@qf10, 10)
    query_and_profile(@qf100, 100)
    query_and_profile(@qf1k, 1000)
    query_and_profile(@qf10k, 10000)
    query_and_profile(@qf100k, 100000)
  end

  def query_and_profile(query_file, docs_per_user)
    result_file = dirs.tmpdir + "fbench_result.#{docs_per_user}.dpu.txt"
    label = "query-#{docs_per_user}.dpu"
    fillers = [parameter_filler("type", "query"),
               parameter_filler("docs_per_user", docs_per_user)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => 30,
                 :clients => 1,
                 :append_str => "&timeout=10s",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -1 #{result_file}")
  end

  def teardown
    super
  end

end
