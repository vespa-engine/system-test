# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorCanvass < PerformanceTest

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

  def test_canvass_ranking_expression
    set_description("Test performance of a neural network tensor expression")

    @docs_file_name = dirs.tmpdir + "/docs.json"
    @queries_file_name = dirs.tmpdir + "/queries.txt"
    @num_docs = 10000
    @num_queries = 1

    generate_feed_and_queries
    deploy_and_feed
    run_queries
  end

  def generate_feed_and_queries
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
    @random_generator = Random.new(123456789)
    result = "["
    @num_docs.times do |i|
      result << "," if i > 0
      result << "\n"
      result << "  {\n"
      result << "    \"put\":\"id:test:test::#{i}\",\n"
      result << "    \"fields\":{\n"
      result << "      \"id\":#{i},\n"
      result << "      \"v1\":#{@random_generator.rand},\n"
      result << "      \"v2\":#{@random_generator.rand},\n"
      result << "      \"v3\":#{@random_generator.rand},\n"
      result << "      \"v4\":#{@random_generator.rand},\n"
      result << "      \"v5\":#{@random_generator.rand},\n"
      result << "      \"v6\":#{@random_generator.rand},\n"
      result << "      \"v7\":#{@random_generator.rand}\n"
      result << "    }\n"
      result << "  }"
    end
    result << "\n]\n"
  end

  def generate_queries
    puts "generate_queries"
    file = File.open(@queries_file_name, "w")
    @num_queries.times do |i|
      file.write("/search/?query=sddocname:test\n")
    end
    file.close
  end

  def deploy_and_feed
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").search_dir(selfdir + "search/"))
    start
    feed_and_wait_for_docs("test", @num_docs, :file => @docs_file_name)
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
  end

  def run_queries
    run_fbench_helper("default")
    run_fbench_helper("ludicrous")
  end

  def run_fbench_helper(rank_profile)
    puts "run_fbench_helper(#{rank_profile})"
    copy_query_file
    fillers = [parameter_filler("rank_profile", rank_profile)]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 60, :clients => 1, :append_str => "&ranking=#{rank_profile}&timeout=60"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

