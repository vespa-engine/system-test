# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/search_app'
require 'fileutils'
require 'performance_test'
require 'performance/tensor_constant/tensor_constant_generator'

class TensorConstantPerfTest < PerformanceTest

  PREPARE_TIME = "deploy.prepare_time"
  FILE_DISTRIBUTION_TIME = "deploy.filedistribution_time"

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    super
    set_owner("geirst")
  end

  def feeder_numthreads
      1
  end

  def test_tensor_constant_deploy_and_filedistribution
    set_description("Test that we can deploy an application with a constant tensor of size 300MB (approx 5.97M cells) and distribute with filedistribution")
    @graphs = get_graphs
    @tensor_dir = dirs.tmpdir + "search/"
    generate_tensor_constant(300)
    deploy_and_feed(selfdir + "app/test.sd")
  end

  def test_tensor_constant_deploy_and_filedistribution_lz4
    set_description("Test that we can deploy an application with a constant tensor of size 300MB (approx 5.97M cells) and distribute with filedistribution, using lz4")
    @graphs = get_graphs_lz4
    @tensor_dir = dirs.tmpdir + "search/"
    generate_tensor_constant_lz4(300)
    deploy_and_feed(selfdir + "app_lz4/test.sd")
  end

  def deploy_and_feed(test_app)
    out = deploy_app(SearchApp.new.sd(selfdir + "app_no_tensor/test.sd").
              num_hosts(@num_hosts).
              configserver("node2"))
    # Start Vespa so services are up when the next deployment is done.
    # File distribution will start as part of deploy prepare
    # so this makes sure that we measure time for file distribution to
    # finish and do not include startup time of services
    start
    deploy_app_and_sample_time(SearchApp.new.sd(test_app).
                               num_hosts(@num_hosts).
                               configserver("node2").
                               search_dir(@tensor_dir),
                               get_generation(out).to_i + 1)
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")
    assert_relevancy("query=sddocname:test", 9.0)
  end

  def get_graphs
    [
      get_deploy_graph(PREPARE_TIME, 11, 15),
      get_deploy_graph(FILE_DISTRIBUTION_TIME, 17, 19.5)
    ]
  end

  def get_graphs_lz4
    [
      get_deploy_graph(PREPARE_TIME, 2.0, 5.5),
      get_deploy_graph(FILE_DISTRIBUTION_TIME, 14, 20)
    ]
  end

  def get_deploy_graph(name, y_min, y_max)
    {
      :x => "blank",
      :y => name,
      :title => "Historic #{name} in seconds",
      :y_min => y_min,
      :y_max => y_max,
      :historic => true
    }
  end

  def generate_tensor_constant(mb)
    FileUtils.mkdir_p(@tensor_dir)
    tensor_constant_file = "#{@tensor_dir}tensor_constant.#{mb}MB.json"
    TensorConstantGenerator.gen_tensor_constant(tensor_constant_file, mb * 1024 * 1024)
    return tensor_constant_file
  end

  def generate_tensor_constant_lz4(mb)
    tensor_constant_file = generate_tensor_constant(mb)

    compressed_file = tensor_constant_file + ".lz4"

    system("lz4 #{tensor_constant_file} #{compressed_file}")
    system("rm #{tensor_constant_file}")
  end

  def deploy_app_and_sample_time(app, next_generation)
    wait_for_config_thread = Thread.new {
      # wait for config (when new config has arrived file distribution is guaranteed to be finished)
      puts "Waiting for config generation #{next_generation}"
      vespa.search['search'].first.wait_for_config_generation(next_generation)
      puts "Got config generation #{next_generation}"
    }

    out, upload_time, prepare_time, activate_time = deploy_app(app, {:collect_timing => true, :separate_upload_and_prepare => true})
    prepare_finished = Time.now.to_f - activate_time

    wait_for_config_thread.join
    file_distribution_time = Time.now.to_f - prepare_finished

    puts "deploy_app_and_sample_time: prepare_time=#{prepare_time}, file_distribution_time=#{file_distribution_time}"
    write_report([metric_filler(PREPARE_TIME, prepare_time),
                  metric_filler(FILE_DISTRIBUTION_TIME, file_distribution_time)])
  end

  def teardown
    super
  end

end
