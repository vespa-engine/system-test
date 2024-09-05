# Copyright Vespa.ai. All rights reserved.
require 'performance_test'

class OnnxModel < PerformanceTest

  def initialize(*args)
    super(*args)
  end

  def can_share_configservers?
    false
  end

  def setup
    super
    set_owner("hmusum")
    set_description("Test performance of deploying an app with a large ONNX model")

    @node = @vespa.nodeproxies.first[1]
    # Set start and max heap equal to avoid a lot of GC while running test
    override_environment_setting(@node, "VESPA_CONFIGSERVER_JVMARGS", "-Xms2g -Xmx2g")

    @onnx_filename = "ranking_model.onnx"
  end

  def test_onnx_deploy
    downloaded_file = fetch_model
    # For debugging when model has already been downloaded
    # downloaded_file = "/opt/vespa/tmp/ranking_model.onnx"

    # Warmup
    app_handle = do_transfer_app(downloaded_file, {})
    deploy_transfered(app_handle, {})

    total_deploy_time = 0.0
    total_upload_time = 0.0
    total_prepare_time = 0.0
    total_activate_time = 0.0
    run_count = 3
    run_count.times do |i|
      out, upload_time, prepare_time, activate_time = deploy_transfered(app_handle, {:separate_upload_and_prepare => true, :collect_timing => true, :skip_create_model => true})
      deploy_time = (upload_time + prepare_time + activate_time).to_f
      total_deploy_time = total_deploy_time + deploy_time
      total_upload_time = total_upload_time + upload_time
      total_prepare_time = total_prepare_time + prepare_time
      total_activate_time = total_activate_time + activate_time
    end

    avg_upload_time = total_upload_time / run_count
    avg_prepare_time = total_prepare_time / run_count
    avg_activate_time = total_activate_time / run_count
    avg_deploy_time = total_deploy_time / run_count
    puts "Average deploy times: total(#{avg_deploy_time}), upload(#{avg_upload_time}) prepare(#{avg_prepare_time}), activate(#{avg_activate_time})"

    metrics = [metric_filler("config.time.deploy", avg_deploy_time),
               metric_filler("config.time.deploy.upload", avg_upload_time),
               metric_filler("config.time.deploy.prepare", avg_prepare_time),
               metric_filler("config.time.deploy.activate", avg_activate_time)]
    write_report(metrics)
  end

  def fetch_model
    remote_file = "https://data.vespa-cloud.com/tests/performance/#{@onnx_filename}"
    local_file = "#{Environment.instance.vespa_home}/tmp/#{@onnx_filename}"
    cmd = "wget -O'#{local_file}' '#{remote_file}'"
    puts "Running command #{cmd}"
    result = `#{cmd}`
    puts "Result: #{result}"

    local_file
  end

  def do_transfer_app(downloaded_file, params={})
    transfer_app(selfdir + "app", nil, params.merge({:files => { downloaded_file => "files/#{@onnx_filename}"}}))
  end

  def teardown
    super
  end

end
