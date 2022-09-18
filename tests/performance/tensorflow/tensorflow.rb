# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorFlow < PerformanceTest

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

  def do_not_test_tensorflow
    set_description("Test performance of a model imported from TensorFlow")

    @docs_file_name = dirs.tmpdir + "/docs.json"
    @queries_file_name = dirs.tmpdir + "/queries.txt"
    @num_docs = 100
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
      result << "      \"image\":{\n"
      result << "        \"cells\":[\n"
      784.times do |j|
        result << "," if j > 0
        result << "          {\"address\":{\"d0\":\"0\",\"d1\":\"#{j}\"},\"value\":#{@random_generator.rand}}"
      end
      result << "        ]\n"
      result << "      }\n"
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
    deploy(selfdir + "/app")
    vespa.adminserver.logctl("searchnode:eval", "debug=on")
    start
    feed_and_wait_for_docs("test", @num_docs, :file => @docs_file_name)
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
    vespa.adminserver.execute("vespa-logfmt -S searchnode -l debug -N")
    vespa.adminserver.logctl("searchnode:eval", "debug=off")
  end

  def run_queries
    run_fbench_helper("default", 1)
    run_fbench_helper("default_20", 20)
  end

  def run_fbench_helper(rank_profile, clients)
    puts "run_fbench_helper(#{rank_profile})"
    copy_query_file
    fillers = [
        parameter_filler("rank_profile", rank_profile),
        parameter_filler("clients", clients)
    ]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 60, :clients => clients, :append_str => "&ranking=#{rank_profile}&timeout=60"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}.clients-#{clients}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

