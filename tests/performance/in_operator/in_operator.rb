# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'uri'

class InOperatorPerfTest < PerformanceTest

  def setup
    super
    set_owner("geirst")
  end

  def test_in_operator
    set_description("Test performance of IN operator in combination with query filter")
    # See ../range_search/create_docs.cpp for details on how the dataset is generated
    # and which queries that are available for exploring performance.
    # In this test we use explicit ranges by searching for all numbers (tokens) that
    # are included in a range.
    # TODO: Refactor to share common code between RangeSearchPerfTest and this class.
    add_bundle(selfdir + "InItemBuilder.java")
    deploy_app(create_app)
    @container = vespa.container.values.first
    compile_create_docs
    start

    @op_hits_ratios = [1, 5, 10, 50, 100, 200]
    @filter_hits_ratios = [1, 5, 10, 50, 100, 150, 200]
    @tokens_in_op = [1, 10, 100, 1000, 10000, 100000]
    @num_docs = 10000000
    feed_docs
    validate_queries
    run_query_and_profile
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").
      threads_per_search(1).
      search_chain(SearchChain.new.add(Searcher.new("ai.vespa.test.InItemBuilder")))
  end

  def compile_create_docs
    tmp_bin_dir = @container.create_tmp_bin_dir
    @create_docs = "#{tmp_bin_dir}/create_docs"
    @container.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -g -O3 -o #{@create_docs} #{selfdir}../range_search/create_docs.cpp")
  end

  def feed_docs
    command = "#{@create_docs} -d #{@num_docs}"
    run_stream_feeder(command, [])
  end

  def calc_hits(hits_ratio)
    @num_docs * hits_ratio / 1000
  end

  def run_query_and_profile
    for o in @op_hits_ratios do
      for t in [100] do
        hits = calc_hits(o)
        if t <= hits
          query_and_profile(o, t, 0, false)
        end
      end
    end
    for t in @tokens_in_op do
      for o in [10, 100] do
        hits = calc_hits(o)
        if t <= hits
          query_and_profile(o, t, 0, false) unless t == 100 # This case is already tested above
          query_and_profile(o, t, 0, true)
        end
      end
    end
    for f in @filter_hits_ratios do
      for t in [100, 100000] do
        query_and_profile(100, t, f, false)
        query_and_profile(100, t, f, true)
      end
    end
  end

  def get_query(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    # Lower and upper must match the spec in create_docs.cpp
    lower = op_hits_ratio * 10000000 + tokens_in_op
    upper = lower + tokens_in_op
    filter = ""
    if filter_hits_ratio > 0
      filter = " and filter = #{filter_hits_ratio}"
    end
    field_name = "v_#{tokens_in_op}"
    "/search/?" + URI.encode_www_form("yql" => "select * from sources * where #{not_in ? '!' : ''}(#{field_name} in (#{lower}))#{filter}",
                                      "inbuilder.lower" => lower + 1,
                                      "inbuilder.upper" => upper,
                                      "hits" => "0")
  end

  def get_filter_query(filter_hits_ratio)
    URI.encode_www_form("yql" => "select * from sources * where filter = #{filter_hits_ratio}",
                                 "hits" => "0")
  end

  def get_label(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    "query_o#{op_hits_ratio}_t#{tokens_in_op}_f#{filter_hits_ratio}#{not_in ? '_not' : ''}"
  end

  def query_file_name(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    label = get_label(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    dirs.tmpdir + "#{label}.txt"
  end

  def write_query_file(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    file_name = query_file_name(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    File.open(file_name, 'w') do |f|
      f.puts(get_query(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in))
    end
    file_name
  end

  def validate_queries
    for o in @op_hits_ratios do
      for t in @tokens_in_op do
        hits = calc_hits(o)
        if t <= hits
          query = get_query(o, t, 0, false)
          assert_hitcount(query, hits)

          query = get_query(o, t, 0, true)
          assert_hitcount(query, @num_docs - hits)
        end
      end
    end
    for f in @filter_hits_ratios do
      hits = calc_hits(f)
      query = get_filter_query(f)
      assert_hitcount(query, hits)
    end
  end

  def copy_to_container(source_file)
    dest_dir = dirs.tmpdir + "queries"
    @container.copy(source_file, dest_dir)
    dest_file = dest_dir + "/" + File.basename(source_file)
  end

  def query_and_profile(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    local_query_file = write_query_file(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    container_query_file = copy_to_container(local_query_file)
    label = get_label(op_hits_ratio, tokens_in_op, filter_hits_ratio, not_in)
    result_file = dirs.tmpdir + "fbench_result_#{label}.txt"
    fillers = [parameter_filler("label", label),
               parameter_filler("op_hits_ratio", op_hits_ratio),
               parameter_filler("tokens_in_op", tokens_in_op),
               parameter_filler("filter_hits_ratio", filter_hits_ratio),
               parameter_filler("not_in", not_in)]
    profiler_start
    run_fbench2(@container,
                container_query_file,
                {:runtime => 10,
                 :clients => 1,
                 :append_str => "&timeout=10s&ranking.profile=unranked",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -12 #{result_file}")
  end

  def teardown
    super
  end

end
