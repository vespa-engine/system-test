# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorReplaceMaxReduceProdJoinPerfTest < PerformanceTest

  LB = '%7B'
  RB = '%7D'

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

    @docs_file_name = dirs.tmpdir + "/docs.json"
    @queries1_file_name = dirs.tmpdir + "/queries1.txt"
    @queries2_file_name = dirs.tmpdir + "/queries2.txt"
    @num_docs = 100000
    @num_queries = 1000

    generate_feed_and_queries
    deploy_and_feed
    run_queries
  end

  def generate_feed_and_queries
    @random_generator = Random.new(123456789)
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
      nums = {}
      while nums.size < 3
         nums[@random_generator.rand(1000)] = 1.0
      end
      nums = nums.keys
      result << "      \"longarray\":#{nums},\n"
      result << "      \"strten\":{\"cells\":{"
      result << " \"#{nums[0]}\": 1.0, \"#{nums[1]}\": 1.0, \"#{nums[2]}\": 1.0 }}\n"
      result << "    }\n"
      result << "  }"
    end
    result << "\n]\n"
  end

  def generate_queries
    puts "generate_queries"
    file1 = File.open(@queries1_file_name, "w")
    file2 = File.open(@queries2_file_name, "w")
    @num_queries.times do |i|
      wset = generate_random_wset(50)
      file1.write("/search/?query=sddocname:test&rankproperty.weights=#{format1(wset)}\n")
      file2.write("/search/?query=sddocname:test&ranking.features.query(qwten)=#{format2(wset)}\n")
    end
    file1.close
    file2.close
  end

  def format1(wset)
    result = ""
    wset.each_pair do |key,weight|
      result << "," if result != ""
      result << "#{key}:#{weight}"
    end
    return LB + result + RB
  end

  def format2(wset)
    result = ""
    wset.each_pair do |key,weight|
      result << "," if result != ""
      result << "#{LB}x:#{key}#{RB}:#{weight}"
    end
    return LB + result + RB
  end

  def generate_random_wset(num_entries)
    limit = [999, num_entries + 1].max
    unique_keys = (0..limit).to_a.shuffle
    wset = {}
    num_entries.times do |i|
      key = unique_keys[i].to_s
      weight = @random_generator.rand(10000)
      wset[key] = weight
    end
    return wset
  end

  def deploy_and_feed
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", @num_docs, :file => @docs_file_name)
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
  end

  def run_queries
    run_fbench_helper("without_replacement")
    run_fbench_helper("halfmodern")
    run_fbench_helper("halfmoderndirect")
    run_fbench_helper("modern", @queries2_file_name)
    run_fbench_helper("with_replacement")
  end

  def run_fbench_helper(rank_profile, queryfile = @queries1_file_name)
    puts "run_fbench_helper(#{rank_profile})"
    copy_query_file
    fillers = [parameter_filler("rank_profile", rank_profile)]
    profiler_start
    run_fbench2(@container,
                queryfile,
                {:runtime => 30, :clients => 1, :append_str => "&ranking=#{rank_profile}&summary=id&timeout=10"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}")
  end

  def copy_query_file
    @container.copy(@queries1_file_name, File.dirname(@queries1_file_name))
    @container.copy(@queries2_file_name, File.dirname(@queries2_file_name))
  end

end

