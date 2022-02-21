# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'performance_test'

class OnnxModel < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def setup
    super
    set_owner("hmusum")
    set_description("Test performance of deploying an app with a large ONNX model")
  end

  def test_onnx_deploy
    fetch_model

    prepare_time = 0.0
    activate_time = 0.0
    run_count = 2
    run_count.times do |i|
      out, upload, prepare, activate = deploy(selfdir + "app", nil, {:collect_timing => true})
      deploy_time = (prepare_time + activate_time).to_f
      prepare_time = prepare_time + prepare.to_f
      activate_time = activate_time + activate.to_f
    end

    avg_prepare_time = prepare_time / run_count
    avg_activate_time = activate_time / run_count
    avg_deploy_time = avg_prepare_time + avg_activate_time
    puts "Average deploy times: total(#{avg_deploy_time}), prepare(#{avg_prepare_time}), activate(#{avg_activate_time})"

    metrics = [metric_filler("config.time.deploy", avg_deploy_time),
               metric_filler("config.time.deploy.prepare", avg_prepare_time),
               metric_filler("config.time.deploy.activate", avg_activate_time)]
    write_report(metrics)
  end

  def fetch_model
    @node = vespa.nodeproxies.first[1]
    # Get ONNX model from public S3 bucket through data.vespa.oath.cloud
    file = @node.fetchfiles(:webhost => "data.vespa.oath.cloud",
                            :file => "tests/performance/ranking_model.onnx",
                            :nocache => true,
                            :nochecksum => true)
             .first
    puts "node=#{@node.hostname}, file=#{file}, selfdir=#{selfdir}"
    @node.execute("cp #{file} " + selfdir + "app/files/ranking_model.onnx")
  end

end
