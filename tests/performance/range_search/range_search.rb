# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'uri'

class RangeSearchPerfTest < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def test_range_search
    set_description("Test range search performance in combination with query filters")
    # See create_docs.cpp for details in how the dataset is generated
    # and which range queries that are available for exploring performance.
    deploy_app(create_app)
    @container = vespa.container.values.first
    compile_create_docs
    start

    # This matches the documents created by create_docs.cpp
    @hits_ratios = [1, 10, 50, 100, 200, 500]
    @values_in_range = [1, 10, 100, 1000, 10000]
    @num_docs = 10000000
    feed_docs
    validate_queries
    run_query_and_profile
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
       threads_per_search(1)
  end

  def compile_create_docs
    tmp_bin_dir = @container.create_tmp_bin_dir
    @create_docs = "#{tmp_bin_dir}/create_docs"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@create_docs} #{selfdir}/create_docs.cpp")
  end

  def feed_docs
    command = "#{@create_docs} -d #{@num_docs}"
    run_stream_feeder(command, [])
  end

  def calc_hits(hits_ratio)
    @num_docs * hits_ratio / 1000
  end

  def run_query_and_profile
    for r in @hits_ratios do
      for v in @values_in_range do
        hits = calc_hits(r)
        if v <= hits
          query_and_profile(r, v, 0)
        end
      end
    end
    for f in @hits_ratios do
      for r in @hits_ratios do
        if f != r
          query_and_profile(r, 100, f)
        end
      end
    end
  end

  def get_query(range_hits_ratio, values_in_range, filter_hits_ratio)
    # Lower and upper must match the spec in create_docs.cpp
    lower = range_hits_ratio * 100000 + values_in_range
    upper = lower + values_in_range
    filter = ""
    if filter_hits_ratio > 0
      filter = " and filter = #{filter_hits_ratio}"
    end
    "/search/?" + URI.encode_www_form("yql" => "select * from sources * where range(values, #{lower}, #{upper})#{filter}",
                                      "hits" => "0")
  end

  def get_filter_query(filter_hits_ratio)
    URI.encode_www_form("yql" => "select * from sources * where filter = #{filter_hits_ratio}",
                                 "hits" => "0")
  end

  def query_file_name(range_hits_ratio, values_in_range, filter_hits_ratio)
    dirs.tmpdir + "query_r#{range_hits_ratio}_v#{values_in_range}_f#{filter_hits_ratio}.txt"
  end

  def write_query_file(range_hits_ratio, values_in_range, filter_hits_ratio)
    file_name = query_file_name(range_hits_ratio, values_in_range, filter_hits_ratio)
    File.open(file_name, 'w') do |f|
      f.puts(get_query(range_hits_ratio, values_in_range, filter_hits_ratio))
    end
    file_name
  end

  def validate_queries
    for r in @hits_ratios do
      for v in @values_in_range do
        hits = calc_hits(r)
        if v <= hits
          query = get_query(r, v, 0)
          puts query
          assert_hitcount(query, hits)
        end
      end
    end
    for f in @hits_ratios do
      hits = calc_hits(f)
      query = get_filter_query(f)
      puts query
      assert_hitcount(query, hits)
    end
  end

  def copy_to_container(source_file)
    dest_dir = dirs.tmpdir + "queries"
    @container.copy(source_file, dest_dir)
    dest_file = dest_dir + "/" + File.basename(source_file)
  end

  def query_and_profile(range_hits_ratio, values_in_range, filter_hits_ratio)
    local_query_file = write_query_file(range_hits_ratio, values_in_range, filter_hits_ratio)
    container_query_file = copy_to_container(local_query_file)
    label = "query_r#{range_hits_ratio}_v#{values_in_range}_f#{filter_hits_ratio}"
    result_file = dirs.tmpdir + "fbench_result_#{label}.txt"
    fillers = [parameter_filler("range_hits_ratio", range_hits_ratio),
               parameter_filler("values_in_range", values_in_range),
               parameter_filler("filter_hits_ratio", filter_hits_ratio),
               parameter_filler("fast_search", true)]
    profiler_start
    run_fbench2(@container,
                container_query_file,
                {:runtime => 10,
                 :clients => 1,
                 :append_str => "&timeout=10s",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -12 #{result_file}")
  end

  def teardown
    super
  end

end
