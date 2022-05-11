# coding: utf-8
# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'

class TensorUpdatePerfTest < PerformanceTest

  UPDATE_TYPE = "update_type"
  TENSOR_SIZE = "tensor_size"

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def create_app
    SearchApp.new.sd(selfdir + "test.sd").disable_flush_tuning.
      container(Container.new.search(Searching.new).
                  jvmoptions("-Xms8g -Xmx8g"))
  end

  def test_tensor_update
    set_description("Test feed performance for assign and modify updates on dense tensors")
    deploy_app(create_app)
    start
    compile_data_generator
    @num_docs = 100000
    feed_docs(@num_docs)

    feed_and_profile("assign", @num_docs, 10, 10)
    feed_and_profile("assign", @num_docs, 5, 100)
    feed_and_profile("assign", @num_docs/10, 5, 1000)

    feed_and_profile("modify", @num_docs, 10, 10)
    feed_and_profile("modify", @num_docs, 10, 100)
    feed_and_profile("modify", @num_docs, 10, 1000)
  end

  def feeder_numthreads
      3
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
