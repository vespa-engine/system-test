# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/search_app'
require 'fileutils'
require 'performance_test'
require 'performance/tensor_constant/tensor_constant_generator'

class TensorConstantPerfTest < PerformanceTest

  TOTAL_TIME = "deploy.total_time"
  PREPARE_TIME = "deploy.prepare_time"
  ACTIVATE_TIME = "deploy.activate_time"
  FILE_DISTRIBUTION_TIME = "deploy.file_distribution_time"

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
    deploy_app(SearchApp.new.sd(selfdir + "app_no_tensor/test.sd").
               num_hosts(@num_hosts).
               configserver("node2"))
    # Start here so services are up when the next deploy happens
    # then file distribution will start as part of deploy prepare
    # and we measure time for file distribution to finish (as opposed
    # to startup time of services)
    start
    deploy_app_and_sample_time(SearchApp.new.sd(test_app).
                               num_hosts(@num_hosts).
                               configserver("node2").
                               search_dir(@tensor_dir))
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")
    assert_relevancy("query=sddocname:test", 9.0)
  end

  def get_graphs
    [
      get_deploy_graph(TOTAL_TIME, 6, 11),
      get_deploy_graph(PREPARE_TIME, 6, 10),
      get_deploy_graph(ACTIVATE_TIME, nil, nil),
      get_deploy_graph(FILE_DISTRIBUTION_TIME, 8, 19)
    ]
  end

  def get_graphs_lz4
    [
      get_deploy_graph(TOTAL_TIME, 1.2, 2.6),
      get_deploy_graph(PREPARE_TIME, 1.0, 2.6),
      get_deploy_graph(ACTIVATE_TIME, nil, nil),
      get_deploy_graph(FILE_DISTRIBUTION_TIME, 12, 16)
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
    puts "generate_tensor_constant"
    FileUtils.mkdir_p(@tensor_dir)
    tensor_constant_file = "#{@tensor_dir}tensor_constant.#{mb}MB.json"
    TensorConstantGenerator.gen_tensor_constant(tensor_constant_file, mb * 1024 * 1024)
    return tensor_constant_file
  end

  def generate_tensor_constant_lz4(mb)
    tensor_constant_file = generate_tensor_constant(mb)

    puts "compress_tensor_constant"
    compressed_file = tensor_constant_file + ".lz4"

    run_system_command("lz4 #{tensor_constant_file} #{compressed_file}")
    run_system_command("rm #{tensor_constant_file}")

    # debug
    puts "Contents of tensor dir: " + Dir.glob("#{@tensor_dir}/**/*").join(", ")
    puts "Contents of temp dir: " + Dir.glob("#{dirs.tmpdir}/**/*").join(", ")
  end

  def run_system_command(cmd)
    res = system(cmd)
    puts "Command \"#{cmd}\" returned %s" % res
  end

  def deploy_app_and_sample_time(app)
    out, upload_time, prepare_time, activate_time = deploy_app(app, {:collect_timing => true})
    start_file_distribution = Time.now
    total_time = (prepare_time + activate_time).to_f
    # wait for config (when new config has arrived file distribution is guaranteed to be finished)
    vespa.search['search'].first.wait_for_config_generation(get_generation(out).to_i)
    # Subtract activate time, since file distribution starts at end of prepare
    file_distribution_time = Time.now - start_file_distribution - activate_time
    puts "deploy_app_and_sample_time: total_time=#{total_time}, prepare_time=#{prepare_time}, activate_time=#{activate_time}, file_distribution_time=#{file_distribution_time}"
    write_report([metric_filler(TOTAL_TIME, total_time),
                  metric_filler(PREPARE_TIME, prepare_time),
                  metric_filler(ACTIVATE_TIME, activate_time),
                  metric_filler(FILE_DISTRIBUTION_TIME, file_distribution_time)])
  end

  def teardown
    super
  end

end
