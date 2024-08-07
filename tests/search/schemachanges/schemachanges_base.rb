# Copyright Vespa.ai. All rights reserved.

module SchemaChangesBase

  def use_sdfile(sdfile)
    dest_sd = "#{dirs.tmpdir}test.sd"
    command = "cp #{@test_dir}#{sdfile} #{dest_sd}"
    success = system(command)
    puts "use_sdfile(#{sdfile}): command='#{command}', success='#{success}'"
    assert(success)
    dest_sd
  end

  def postdeploy_wait(deploy_output)
    wait_for_application(vespa.container.values.first, deploy_output)
    config_generation = get_generation(deploy_output).to_i
    wait_for_config_generation_proxy(config_generation)
    wait_for_reconfig(config_generation, 600)
  end

  def redeploy(sdfile, validation_override = nil)
    app = SearchApp.new.sd(use_sdfile(sdfile))
    app = app.validation_override(validation_override) if validation_override
    deploy_output = deploy_app(app)
    wait_for_content_cluster_config_generation(deploy_output)
    postdeploy_wait(deploy_output)
    return deploy_output
  end

  def add_attribute_aspect(sd_file)
    redeploy(sd_file)
    status = vespa.search["search"].first.get_proton_status
    assert_match(/"WARNING","state=ONLINE configstate=NEED_RESTART","DocumentDB delaying attribute aspects changes in config/, status, status)
  end

  def remove_attribute_aspect(sd_file)
    redeploy(sd_file, "indexing-change")
    status = vespa.search["search"].first.get_proton_status
    assert_match(/"WARNING","state=ONLINE configstate=NEED_RESTART","DocumentDB delaying attribute aspects changes in config/, status, status)
  end

  def activate_attribute_aspect(exp_hits)
    restart_proton("test", exp_hits)
    status = vespa.search["search"].first.get_proton_status
    assert_match(/"OK","state=ONLINE configstate=OK",""/, status, status)
  end

  def wait_for_content_cluster_config_generation(deploy_output)
    gen = get_generation(deploy_output).to_i
    vespa.storage["search"].wait_until_content_nodes_have_config_generation(gen)
  end

  def enable_proton_debug_log
    proton = vespa.search["search"].first
    proton.logctl2("proton.server.storeonlyfeedview", "all=on")
    proton.logctl2("proton.persistenceengine.persistenceengine", "all=on")
    proton.logctl2("proton.server.buckethandler", "all=on")
    proton.logctl2("proton.persistenceengine.document_iterator", "all=on")
  end

  def assert_reprocess_event_logs
    assert_log_matches(/.reprocess\.documents\.start.*documentsubdb":"test\.0\.ready/)
    assert_log_matches(/.reprocess\.documents\.progress.*documentsubdb":"test\.0\.ready.*progress":1\.0/)
    assert_log_matches(/.reprocess\.documents\.complete.*documentsubdb":"test\.0\.ready/)
  end

  def assert_remove_reprocess_event_logs(field_name, docs_populated)
    assert_log_matches(/.populate\.documentfield\.start.*test\.0\.ready\.documentfield\.#{field_name}/)
    assert_reprocess_event_logs
    assert_log_matches(/.populate\.documentfield\.complete.*test\.0\.ready\.documentfield\.#{field_name}.*documents\.populated":#{docs_populated}/)
  end

  def assert_add_reprocess_event_logs(field_name, docs_populated)
    assert_log_matches(/.populate\.attribute\.start.*test\.0\.ready\.attribute\.#{field_name}/)
    assert_reprocess_event_logs
    assert_log_matches(/.populate\.attribute\.complete.*test\.0\.ready\.attribute\.#{field_name}.*documents\.populated":#{docs_populated}/)
  end

end
