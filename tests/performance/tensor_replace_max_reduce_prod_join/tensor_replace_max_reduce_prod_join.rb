# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorReplaceMaxReduceProdJoinPerfTest < PerformanceTest

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

  def test_replace_max_reduce_prod_join_expression
    set_description("Test performance of the max-reduce-prod-join tensor expression replacement optimization")

    @graphs = get_graphs
    @docs_file_name = dirs.tmpdir + "/docs.json"
    @queries_file_name = dirs.tmpdir + "/queries.txt"
    @num_docs = 100000
    @num_queries = 1000

    generate_feed_and_queries
    deploy_and_feed
    run_queries
  end

  def get_graphs
    [
      get_graph("without_replacement", 41.5, 55.0),
      get_graph("with_replacement", 4.4, 5.4)
    ]
  end

  def get_graph(rank_profile, y_min, y_max)
    {
      :x => "rank_profile",
      :y => "latency",
      :title => "Historic latency for rank profile '#{rank_profile}'",
      :filter => {"rank_profile" => rank_profile},
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
    file = File.open(@docs_file_name, "w")
    file.write(generate_docs)
    file.close
  end

  def generate_docs
    result = "["
    @num_docs.times do |i|
      result << "," if i > 0
      result << "\n"
      result << "  {\n"
      result << "    \"put\":\"id:test:test::#{i}\",\n"
      result << "    \"fields\":{\n"
      result << "      \"id\":#{i},\n"
      result << "      \"longarray\":[#{Random.rand(1000)},#{Random.rand(1000)},#{Random.rand(1000)}]\n"
      result << "    }\n"
      result << "  }"
    end
    result << "\n]\n"
  end

  def generate_queries
    puts "generate_queries"
    file = File.open(@queries_file_name, "w")
    @num_queries.times do |i|
      file.write("/search/?query=sddocname:test&rankproperty.weights=" + generate_random_wset(50) + "\n")
    end
    file.close
  end

  def generate_random_wset(num_entries)
    limit = [999, num_entries + 1].max
    unique_keys = (0..limit).to_a.shuffle
    result = "%7B"
    num_entries.times do |i|
      result << "," if i > 0
      result << unique_keys[i].to_s + ":" + Random.rand(10000).to_s
    end
    result << "%7D"
    result
  end

  def deploy_and_feed
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", @num_docs, :file => @docs_file_name)
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
  end

  def run_queries
    run_fbench_helper("without_replacement")
    run_fbench_helper("with_replacement")
  end

  def run_fbench_helper(rank_profile)
    puts "run_fbench_helper(#{rank_profile})"
    copy_query_file
    fillers = [parameter_filler("rank_profile", rank_profile)]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 30, :clients => 1, :append_str => "&ranking=#{rank_profile}&summary=id&timeout=10"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

