# Copyright Vespa.ai. All rights reserved.

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
    add_bundle_dir(selfdir + 'java', 'streamingtest', {:mavenargs => '-Dmaven.test.skip=true'})
    deploy(selfdir + 'app')
    @container = vespa.container.values.first
    compile_create_docs
    chunks = 5
    write_query_files(chunks)
    start

    feed_and_profile(chunks)
    run_query_and_profile
  end

  def compile_create_docs
    tmp_bin_dir = @container.create_tmp_bin_dir
    @create_docs = "#{tmp_bin_dir}/create_docs"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@create_docs} #{selfdir}/create_docs.cpp")
  end

  def feed_and_profile(chunks)
    # We feed chunks * 500k documents, where each chunk has:
    #   - 100k docs with 10000 users with 10 docs each
    #   - 100k docs with 1000 users with 100 docs each
    #   - 100k docs with 100 users with 1k docs each
    #   - 100k docs with 10 users with 10k docs each
    #   - 100k docs with 1 user with 100k docs each
    spec = "10 #{10000 * chunks} 100 #{1000 * chunks} 1000 #{100 * chunks} 10000 #{10 * chunks} 100000 #{1 * chunks}"
    command = "#{@create_docs} -d 0 #{spec}"
    profiler_start
    run_stream_feeder(command, [parameter_filler("type", "feed")])
    profiler_report("feed")
  end

  def random_vector(count)
    res = []
    count.times do
      res << rand(0...100000) / 100000.0
    end
    res.to_s
  end

  def get_query(user_id)
    "/search/?" + URI.encode_www_form("yql" => "select * from sources * where {targetHits:10}nearestNeighbor(embedding,qemb)",
                                      "input.query(qemb)" => random_vector(384),
                                      "streaming.groupname" => "#{user_id}",
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

  def write_query_files(chunks)
    @qf10 = dirs.tmpdir + "queries.10.dpu.txt"
    @qf100 = dirs.tmpdir + "queries.100.dpu.txt"
    @qf1k = dirs.tmpdir + "queries.1k.dpu.txt"
    @qf10k = dirs.tmpdir + "queries.10k.dpu.txt"
    @qf100k = dirs.tmpdir + "queries.100k.dpu.txt"
    # Must match the same id range used in create_docs.cpp
    id_range = 10000000;
    write_queries(@qf10, 5000, id_range)
    write_queries(@qf100, 1000 * chunks, id_range * 2)
    write_queries(@qf1k, 100 * chunks, id_range * 3)
    write_queries(@qf10k, 10 * chunks, id_range * 4)
    write_queries(@qf100k, 1 * chunks, id_range * 5)
  end

  def run_query_and_profile
    query_and_profile(@qf10, 10)
    query_and_profile(@qf100, 100)
    query_and_profile(@qf1k, 1000)
    query_and_profile(@qf10k, 10000)
    query_and_profile(@qf100k, 100000)
  end

  def copy_to_container(source_file)
    dest_dir = dirs.tmpdir + "qf"
    @container.copy(source_file, dest_dir)
    dest_file = dest_dir + "/" + File.basename(source_file)
  end

  def query_and_profile(query_file, docs_per_user)
    container_query_file = copy_to_container(query_file)
    result_file = dirs.tmpdir + "fbench_result.#{docs_per_user}.dpu.txt"
    label = "query-#{docs_per_user}.dpu"
    fillers = [parameter_filler("type", "query"),
               parameter_filler("docs_per_user", docs_per_user)]
    profiler_start
    run_fbench2(@container,
                container_query_file,
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
