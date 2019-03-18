# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorFlowBlogExperiment < PerformanceTest

  def initialize(*args)
    super(*args)
    @num_hosts = 8
  end

  def setup
    super
    set_owner("lesters")
  end

  def teardown
    super
  end

  # Test is currently disabled
  def no_test_blog_model_with_increasing_content_nodes
    set_description("Test performance of blog recommendation model with increasing number of content nodes")

    @graphs = get_graphs
    @blogs_file_name = dirs.tmpdir + "/blogs.json"
    @queries_file_name = dirs.tmpdir + "/queries.txt"
    @cluster_name = "blog_cluster"

    srand(123456789)
    generate_queries

    # deploy application
    add_bundle_dir(selfdir + "bundle", "tensorflow")
    deploy(selfdir + "/app", nil, nil, {:num_hosts => 8})
    start
    @container = (vespa.qrserver["0"] or vespa.container.values.first)

    # stop all content nodes except one (one container and one content node left standing)
    1.upto(6) do |content_node_id|
        vespa.stop_content_node(@cluster_name, content_node_id.to_s)
    end

    # run test on a single content node
    feed_and_run_queries(1)

    # start a new content node, feed so that all content nodes have same amount of documents, run test
    1.upto(6) do |content_node_id|
        start_node_and_wait(@cluster_name, content_node_id)
        feed_and_run_queries(content_node_id + 1)
    end

  end

  def feed_and_run_queries(content_nodes)
    generate_feed((content_nodes-1) * 1000, 1000)
    feed_and_wait_for_docs("blog_post", content_nodes * 1000, :file => @blogs_file_name, :json => true)
    run_queries(content_nodes)
  end

  def start_node_and_wait(cluster_name, node_idx)
    node = vespa.storage[cluster_name].storage[node_idx.to_s]
    puts "******** start_node_and_wait(#{node.to_s}) ********"
    vespa.start_content_node(cluster_name, node.index, 120)
    node.wait_for_current_node_state('u')
    vespa.storage[cluster_name].wait_until_ready(120)
  end

  def get_graphs
    graphs = []
    1.upto(7) do |i|
      graphs.push(get_latency_graph(0.0, 100000.0, i))
    end
    1.upto(7) do |i|
      graphs.push(get_qps_graph(0.0, 100000.0, i))
    end
    return graphs
  end

  def get_latency_graph(y_min, y_max, content_nodes)
    {
      :x => "rank_profile",
      :y => "latency",
      :title => "Historic latency for #{content_nodes} content nodes",
      :filter => {'content_nodes' => content_nodes},
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

  def get_qps_graph(y_min, y_max, content_nodes)
    {
      :x => "rank_profile",
      :y => "qps",
      :title => "Historic QPS for #{content_nodes} content nodes",
      :filter => {'content_nodes' => content_nodes},
      :historic => true,
      :y_min => y_min,
      :y_max => y_max
    }
  end

  def generate_feed(start_id, num)
    puts "******** generating feed (#{num}) ********"
    file = File.open(@blogs_file_name, "w")
    file.write(generate_blogs(start_id, num))
    file.close
  end

  def generate_blogs(start_id, num)
    result = "["
    num.times do |i|
      result << "," if i > 0
      result << "\n"
      result << "  {\n"
      result << "    \"put\":\"id:blog_post:blog_post::#{i + start_id}\",\n"
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
    puts "******** generating queries ********"
    file = File.open(@queries_file_name, "w")
    file.write("/search/?query=sddocname:blog_post&searchChain=blog\n")
    file.close
  end

  def run_queries(content_nodes)
    run_fbench_helper("first_phase_no_summaries", "no_summary", content_nodes, 100)
    run_fbench_helper("vespa", "no_summary", content_nodes, 100)
    run_fbench_helper("first_phase_with_summaries", "with_summary", content_nodes, 100 * content_nodes)
    run_fbench_helper("tensorflow_single", "with_summary", content_nodes, 100 * content_nodes)
    run_fbench_helper("tensorflow_multiple", "with_summary", content_nodes, 100 * content_nodes)
  end

  def run_fbench_helper(rank_profile, summary, content_nodes, hits)
    puts "******** run_fbench_helper(#{rank_profile}, #{content_nodes}) ********"
    copy_query_file
    fillers = [
        parameter_filler("rank_profile", rank_profile),
        parameter_filler("content_nodes", content_nodes),
    ]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 30, :clients => 64, :append_str => "&hits=#{hits}&ranking=#{rank_profile}&summary=#{summary}&timeout=60&ranking.querycache=true&dispatch.summaries=true"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}-#{content_nodes}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

