# coding: utf-8
# Copyright Vespa.ai. All rights reserved.
require 'performance_test'
require 'app_generator/search_app'
require 'environment'

class TensorUnboundStringLabelsTest < PerformanceTest
  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner('glebashnik')
  end

  def create_app
    SearchApp.new.sd(selfdir + 'test.sd').disable_flush_tuning.
      container(Container.new.search(Searching.new).
        documentapi(ContainerDocumentApi.new).
        jvmoptions('-Xms8g -Xmx8g -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005'))
  end

  def test_feed
    set_description('Test feed performance for unbounded string labels in mapped tensors')
    deploy_app(create_app)
    start
    compile_data_generator
    feed_and_profile(30_000, 1000)
  end

  def feeder_numthreads
    5
  end

  def compile_data_generator
    tmp_bin_dir = vespa.adminserver.create_tmp_bin_dir
    @data_generator = "#{tmp_bin_dir}/data_generator"
    # TODO: make this work on centos7 as well
    vespa.adminserver.execute("g++ -Wl,-rpath,#{Environment.instance.vespa_home}/lib64/ -Wall -g -O3 -o #{@data_generator} #{selfdir}/data_generator.cpp")
  end

  def feed_and_profile(num_docs, tensor_size)
    container = (vespa.qrserver['0'] or vespa.container.values.first)

    profiler_start
    run_stream_feeder(
      "#{@data_generator} #{num_docs} #{tensor_size}",
      [
        parameter_filler('legend', 'test_container_feed_performance'),
        metric_filler('memory.rss', container.memusage_rss(container.get_pid))
      ],
      { :client => :vespa_feed_client }
    )
    profiler_report("d#{num_docs}-t#{tensor_size}")
  end

  def teardown
    super
  end
end
