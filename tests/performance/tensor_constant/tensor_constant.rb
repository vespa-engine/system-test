# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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
    out = deploy_app(create_app(selfdir + "app_no_tensor/test.sd"))
    vespa.configservers["0"].logctl("configserver:com.yahoo.vespa.config.server.session.SessionPreparer", "debug=on")
    # Start Vespa before the next deployment is done. File distribution will start as part of deploy prepare
    # so this makes sure that we do not include startup time of services when measuring file distribution time
    start
    deploy_app_and_sample_time(create_app(schema), get_generation(out).to_i)
    feed_and_wait_for_docs("test", 1, :file => selfdir + "docs.json")
    assert_relevancy("query=sddocname:test", 9.0)
  end

  def create_app(schema)
    app = SearchApp.new.
            sd(schema).
            num_hosts(@num_hosts).
            search_dir(@tensor_dir)
    if (@num_hosts == 2)
      app = app.configserver("node2")
    end
    app
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

  def deploy_app_and_sample_time(app, generation)
    next_generation = generation + 1
    total_prepare_time = 0.0
    total_file_distribution_time = 0.0
    iterations = 2
    iterations.times { |i|

      # wait for config (when new config has arrived file distribution is guaranteed to be finished)
      wait_for_config_thread = Thread.new {
        puts "Waiting for config generation #{next_generation}"
        vespa.search['search'].first.wait_for_config_generation(next_generation, 120)
        puts "Got config generation #{next_generation}"
      }

      out, upload_time, prepare_time, activate_time = deploy_app(app, {:collect_timing => true})
      activate_finished = Time.now.to_f
      total_prepare_time = total_prepare_time + prepare_time

      wait_for_config_thread.join
      # Files will only be distributed on the first deployment, unchanged on the next ones
      if i == 0
        total_file_distribution_time = Time.now.to_f - activate_finished
      end

      next_generation = next_generation + 1
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

  def teardown
    super
  end

end
