# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorFlowBlog < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("lesters")
  end

  def teardown
    super
  end

  def test_tensorflow_vs_vespa_blog_one_content_node
    set_description("Test performance of blog recommendation model Vespa vs TensorFlow")

    @graphs = get_graphs
    @blogs_file_name = dirs.tmpdir + "/blogs.json"
    @queries_file_name = dirs.tmpdir + "/queries.txt"
    @num_blogs = 1000

    generate_feed_and_queries
    deploy_and_feed
    run_queries
  end

  def get_graphs
    [
      get_latency_graph(0.0, 100000.0),
      get_qps_graph(0.0, 100000.0),
    ]
  end

  def get_latency_graph(y_min, y_max)
    {
      :x => "rank_profile",
      :y => "latency",
      :title => "Historic latency",
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

  def get_qps_graph(y_min, y_max)
    {
      :x => "rank_profile",
      :y => "qps",
      :title => "Historic QPS",
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

  def generate_feed_and_queries
    srand(123456789)
    generate_feed
    generate_queries
  end

  def generate_feed
    puts "generate_feed"
    file = File.open(@blogs_file_name, "w")
    file.write(generate_blogs)
    file.close
  end

  def generate_blogs
    result = "["
    @num_blogs.times do |i|
      result << "," if i > 0
      result << "\n"
      result << "  {\n"
      result << "    \"put\":\"id:blog_post:blog_post::#{i}\",\n"
      result << "    \"fields\":{\n"
      result << "      \"post_id\":#{i},\n"
      result << "      \"user_item_cf\":{\n"
      result << "        \"cells\":[\n"
      128.times do |j|
        result << "," if j > 0
        result << "          {\"address\":{\"d0\":0,\"d1\":\"#{j}\"},\"value\":#{Random.rand}}"
      end
      result << "        ]\n"
      result << "      },\n"
      result << "      \"has_user_item_cf\":1\n"
      result << "    }\n"
      result << "  }"
    end
    result << "\n]\n"
  end

  def generate_queries
    puts "generate_queries"
    file = File.open(@queries_file_name, "w")
    file.write("/search/?query=sddocname:blog_post&searchChain=blog\n")
    file.close
  end

  def deploy_and_feed
    add_bundle_dir(selfdir + "bundle", "tensorflow")
    deploy(selfdir + "/app")
    vespa.adminserver.logctl("searchnode:eval", "debug=on")
    start
    feed_and_wait_for_docs("blog_post", @num_blogs, :file => @blogs_file_name, :json => true)
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
    vespa.adminserver.execute("vespa-logfmt -S searchnode -l debug -N")
  end

  def run_queries
    run_fbench_helper("first_phase_no_summaries", "no_summary", 100)
    run_fbench_helper("first_phase_with_summaries", "with_summary", 100)
    run_fbench_helper("vespa", "no_summary", 100)
    run_fbench_helper("tensorflow_single", "with_summary", 100)
    run_fbench_helper("tensorflow_multiple", "with_summary", 100)
    run_fbench_helper("tensorflow_stateless_evaluation", "with_summary", 100)
  end

  def run_fbench_helper(rank_profile, summary, hits)
    puts "run_fbench_helper(#{rank_profile})"
    copy_query_file
    fillers = [
        parameter_filler("rank_profile", rank_profile),
    ]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 30, :clients => 64, :append_str => "&hits=#{hits}&ranking=#{rank_profile}&summary=#{summary}&timeout=60&ranking.querycache=true&dispatch.summaries=true"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

