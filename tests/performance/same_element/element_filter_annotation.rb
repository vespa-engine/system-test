# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class ElementFilterAnnotationPerformance < PerformanceTest
  FBENCH_TIME = 10

  TYPE = "type"
  LABEL = "label"
  ARRAY_LENGTH = "array_length"

  def setup
    set_owner('boeker')
  end

  def test_ultra_sparse_bool_array
    set_description('Test performance of indexing into an array of bools (few true entires) using elementFilter annotation of sameElement operator.')
    run_bool_test(0.00001) # Roughly every 100'000th entry is true
  end

  def test_sparser_bool_array
    set_description('Test performance of indexing into an array of bools (few true entires) using elementFilter annotation of sameElement operator.')
    run_bool_test(0.0001) # Roughly every 10'000th entry is true
  end

  def test_sparse_bool_array
    set_description('Test performance of indexing into an array of bools (few true entires) using elementFilter annotation of sameElement operator.')
    run_bool_test(0.001) # Roughly every 1'000th entry is true
  end

  def test_dense_bool_array
    set_description('Test performance of indexing into an array of bools (many true entries) using elementFilter annotation of sameElement operator.')
    run_bool_test(0.5) # Roughly every second entry is true
  end

  def run_bool_test(true_probability)
    deploy_app(SearchApp.new.sd(selfdir + 'arrays.sd').threads_per_search(1))
    start

    num_documents = 10_000
    array_length = 100_000

    compile_generators
    feed(num_documents, array_length, true_probability)

    # Warm-up
    query_and_benchmark(array_length, "warmup")

    # Benchmark
    query_and_benchmark(array_length, "benchmark-#{true_probability}")
  end

  def compile_generators
    @container = vespa.container.values.first
    @container_tmp_bin_dir = @container.create_tmp_bin_dir
    @adminserver_tmp_bin_dir = vespa.adminserver.create_tmp_bin_dir

    vespa.adminserver.execute("g++ -g -O3 -o #{@adminserver_tmp_bin_dir}/make_docs #{selfdir}make_docs.cpp")
    @container.execute("g++ -g -O3 -o #{@container_tmp_bin_dir}/make_queries #{selfdir}make_queries.cpp")
  end

  def feed(num_documents, array_length, true_probability)
    profiler_start
    command = "#{@adminserver_tmp_bin_dir}/make_docs #{num_documents} #{array_length} #{true_probability}"
    run_stream_feeder(command, [parameter_filler(TYPE, "feed"), parameter_filler(LABEL, "#{num_documents}-docs")])
    profiler_report("feed")
  end

  def query_and_benchmark(array_length, label)
    query_file = dirs.tmpdir + "queries-#{array_length}.txt"
    @container.execute("#{@container_tmp_bin_dir}/make_queries 10000 #{array_length} > #{query_file}")
    puts "Generated on container: #{query_file}"
    result_file = dirs.tmpdir + "fbench_result.#{label}.txt"
    fillers = [parameter_filler(TYPE, "query"),
               parameter_filler(LABEL, label),
               parameter_filler(ARRAY_LENGTH, array_length)]
    profiler_start
    run_fbench2(@container,
                query_file,
                {:runtime => FBENCH_TIME,
                 :clients => 1,
                 :append_str => "&summary=minimal&hits=100&timeout=20s",
                 :result_file => result_file},
                fillers)
    profiler_report(label)
    @container.execute("head -10 #{result_file}")
  end

end
