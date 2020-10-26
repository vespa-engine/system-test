# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class TensorMatrixMatrixProduct < PerformanceTest

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

  def test_tensor_matrix_matrix_products
    set_description("Test of various matrix-matrix products")

    @graphs = get_graphs
    @docs_file_name = dirs.tmpdir + "/docs.json"
    @queries_file_name = dirs.tmpdir + "/queries.txt"
    @constants_dir = dirs.tmpdir + "/search/"
    @num_docs = 100

    generate_feed_and_queries
    deploy_and_feed
    run_queries
  end

  def get_graphs
    [
      get_latency_graph(0.1, 0.3),
      get_qps_graph(4000.0, 7000.0),
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
    generate_constants
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
      result << "      \"vector_512_float\":{\n"
      result << generate_cells_1d("d0", 512)
      result << "      },\n"
      result << "      \"matrix_256x512_float\":{\n"
      result << generate_cells_2d("d0", 256, "d1", 512)
      result << "      },\n"
      result << "      \"matrix_512x256_float\":{\n"
      result << generate_cells_2d("d0", 512, "d1", 256)
      result << "      },\n"
      result << "      \"matrix_256x512_double\":{\n"
      result << generate_cells_2d("d0", 256, "d1", 512)
      result << "      },\n"
      result << "      \"matrix_256x1024_float\":{\n"
      result << generate_cells_2d("d0", 256, "d1", 1024)
      result << "      }\n"
      result << "    }\n"
      result << "  }"
    end
    result << "\n]\n"
  end

  def generate_constants
    puts "generate_constants"
    FileUtils.mkdir_p(@constants_dir)
    write_constant_file("vector_512.json", generate_1d_constant("d0", 512))
    write_constant_file("matrix_256x512.json", generate_2d_constant("d0", 256, "d1", 512))
    write_constant_file("matrix_512x256.json", generate_2d_constant("d0", 512, "d1", 256))
    write_constant_file("matrix_256x1024.json", generate_2d_constant("d0", 256, "d1", 1024))
    write_constant_file("matrix_256x256.json", generate_2d_constant("d0", 256, "d1", 256))
  end

  def write_constant_file(file_name, contents)
    file = File.open("#{@constants_dir}" + file_name, "w")
    file.write(contents)
    file.close
  end

  def generate_2d_constant(d0_name, d0_size, d1_name, d1_size)
    result = "{\n"
    result << generate_cells_2d(d0_name, d0_size, d1_name, d1_size)
    result << "}\n"
  end

  def generate_cells_2d(d0_name, d0_size, d1_name, d1_size)
    result = ""
    result << "  \"cells\":[\n"
    d0_size.times do |d0|
        d1_size.times do |d1|
          result << ",\n" if (d0 > 0 || d1 > 0)
          result << "    {\"address\":{\"#{d0_name}\":\"#{d0}\",\"#{d1_name}\":\"#{d1}\"},\"value\":#{Random.rand}}"
        end
    end
    result << "\n  ]\n"
  end

  def generate_1d_constant(d0_name, d0_size)
    result = "{\n"
    result << generate_cells_1d(d0_name, d0_size)
    result << "}\n"
  end

  def generate_cells_1d(d0_name, d0_size)
    result = ""
    result << "  \"cells\":[\n"
    d0_size.times do |d0|
      result << ",\n" if (d0 > 0)
      result << "    {\"address\":{\"#{d0_name}\":\"#{d0}\"},\"value\":#{Random.rand}}"
    end
    result << "\n  ]\n"
  end

  def generate_queries
    puts "generate_queries"
    file = File.open(@queries_file_name, "w")
    file.write("/search/?query=sddocname:test\n")
    file.close
  end

  def deploy_and_feed
    deploy(selfdir + "/app", nil, nil, {:search_dir => @constants_dir})
    vespa.adminserver.logctl("searchnode:eval", "debug=on")
    start
    feed_and_wait_for_docs("test", @num_docs, :file => @docs_file_name)
    @container = (vespa.qrserver["0"] or vespa.container.values.first)
    vespa.adminserver.execute("vespa-logfmt -S searchnode -l debug -N")
  end

  def run_queries
    run_fbench_helper("vector_vector_512_float")
    run_fbench_helper("vector_matrix_512_float_inner")
    run_fbench_helper("vector_matrix_512_float_outer")
    run_fbench_helper("matrix_product_512_float")
    run_fbench_helper("matrix_product_512_float_inner_outer")
    run_fbench_helper("matrix_product_512_float_outer_outer")
    run_fbench_helper("matrix_product_1024_float")
    run_fbench_helper("matrix_product_512_double")
    run_fbench_helper("gemm_512_float")
    run_fbench_helper("gemm_512_float_inline_join")
  end

  def run_fbench_helper(rank_profile)
    puts "run_fbench_helper(#{rank_profile})"
    copy_query_file
    fillers = [
        parameter_filler("rank_profile", rank_profile),
    ]
    profiler_start
    run_fbench2(@container,
                @queries_file_name,
                {:runtime => 60, :clients => 1, :append_str => "&hits=10&ranking=#{rank_profile}&summary=no_summary&timeout=120&ranking.querycache=true&dispatch.summaries=true"},
                fillers)
    profiler_report("rank_profile-#{rank_profile}")
  end

  def copy_query_file
    @container.copy(@queries_file_name, File.dirname(@queries_file_name))
  end

end

