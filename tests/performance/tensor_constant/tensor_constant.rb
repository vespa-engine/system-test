# Copyright Vespa.ai. All rights reserved.
require 'app_generator/search_app'
require 'fileutils'
require 'performance_test'
require 'performance/tensor_constant/tensor_constant_generator'

class TensorConstantPerfTest < PerformanceTest

  PREPARE_TIME = "deploy.prepare_time"
  FILE_DISTRIBUTION_TIME = "deploy.filedistribution_time"

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("geirst")
  end

  def test_tensor_constant_deploy_and_filedistribution
    set_description("Test that we can deploy an application with a constant tensor of size 300MB (approx 5.97M cells) and distribute with filedistribution")
    @tensor_dir = dirs.tmpdir + "search/"
    generate_tensor_constant(300)
    deploy_and_feed(selfdir + "app/test.sd")
  end

  def test_tensor_constant_deploy_and_filedistribution_lz4
    set_description("Test that we can deploy an application with a constant tensor of size 300MB (approx 5.97M cells) and distribute with filedistribution, using lz4")
    @tensor_dir = dirs.tmpdir + "search/"
    generate_tensor_constant_lz4(300)
    deploy_and_feed(selfdir + "app_lz4/test.sd")
  end

  def deploy_and_feed(schema)
    deploy_app(create_app(selfdir + "app_no_tensor/test.sd"))
    # Start Vespa before the next deployment  is done to make sure that we do not
    # include startup time of services when measuring file distribution time
    start
    deploy_app_and_sample_time(create_app(schema))
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")
    assert_relevancy("query=sddocname:test", 9.0)
  end

  def create_app(schema)
    SearchApp.new.
      sd(schema).
      num_hosts(@num_hosts).
      search_dir(@tensor_dir)
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

  def deploy_app_and_sample_time(app)
    total_prepare_time = 0.0
    total_file_distribution_time = 0.0
    iterations = 2
    iterations.times { |i|
      out, upload_time, prepare_time, activate_time = deploy_app(app, {:collect_timing => true, :skip_create_model => true})
      activate_finished = Time.now.to_f
      total_prepare_time = total_prepare_time + prepare_time

      generation = get_generation(out).to_i
      # wait for config (when new config has arrived file distribution is guaranteed to be finished)
      puts "Waiting for config generation #{generation}"
      vespa.search['search'].first.wait_for_config_generation(generation, 120)
      puts "Got config generation #{generation}"

      # Files will only be distributed on the first deployment, unchanged on the next ones
      if i == 0
        total_file_distribution_time = Time.now.to_f - activate_finished
      end
    }

    avg_prepare_time = total_prepare_time / iterations
    # Files will only be distributed on the first deployment, unchanged on the next ones, so just use total time
    avg_file_distribution_time = total_file_distribution_time
    puts "deploy_app_and_sample_time: prepare_time=#{avg_prepare_time}, file_distribution_time=#{avg_file_distribution_time}, iterations=#{iterations}"

    write_report([metric_filler(PREPARE_TIME, avg_prepare_time),
                  metric_filler(FILE_DISTRIBUTION_TIME, avg_file_distribution_time)])
  end

  def feeder_numthreads
    1
  end

end
