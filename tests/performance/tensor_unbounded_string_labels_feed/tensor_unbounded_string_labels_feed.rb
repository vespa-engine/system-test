# Test feeding with tensors containing millions of labels

class TensorUnboundedStringLabelsFeedPerfTest < PerformanceTest
  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("glebashnik")
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").disable_flush_tuning.
      container(Container.new.search(Searching.new).
        jvmoptions("-Xms8g -Xmx8g"))
  end

  def test_tensor_update
    set_description("Test feed memory use for tensors with unbounded string labels")
    deploy_app(create_app)
    start
    @num_runs = 1
    @num_docs = 100
    @tensor_size = 10
    feed_docs(@num_docs)
    feed_and_profile("put", @num_docs, @num_runs, @tensor_size)
  end

  def feeder_numthreads
    8
  end

  def compile_data_generator
    tmp_bin_dir = vespa.adminserver.create_tmp_bin_dir
    @data_generator = "#{tmp_bin_dir}/data_generator"
    # TODO: make this work on centos7 as well
    vespa.adminserver.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -Wall -g -O3 -o #{@data_generator} #{selfdir}/data_generator.cpp")
  end

  def feed_docs(num_docs)
    feed_stream("#{@data_generator} put #{num_docs}")
  end

  def feed_and_profile(update_type, num_docs, num_runs, tensor_size)
    command = "#{@data_generator} #{update_type} #{num_docs} #{num_runs} #{tensor_size}"
    profiler_start
    run_stream_feeder(command, [parameter_filler(UPDATE_TYPE, update_type), parameter_filler(TENSOR_SIZE, tensor_size)], {})
    profiler_report("#{update_type}-d#{num_docs}-t#{tensor_size}")
  end

  def teardown
    super
  end

end
