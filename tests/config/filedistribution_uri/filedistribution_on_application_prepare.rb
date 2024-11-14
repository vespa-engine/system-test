# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'config/filedistribution_uri/filedistribution_base'

# Note: 2 hosts are needed. If you want to run this by yourself you need to add "--configserverhost some_other_host"
class FileDistributionOnApplicationPrepare < ConfigTest

  include FileDistributionBase

  def can_share_configservers?
    true
  end

  def setup
    set_owner("musum")
    set_description("Tests file distribution happens when preparing an application")
    @valgrind = false
  end

  # Check that file distribution works by verifying that a deployment
  # with an updated bundle is distributed to the node, even though
  # multiple deployments happened between preparing and activating
  # that deployment
  def test_filedistribution_on_application_prepare
    initial = add_bundle_dir(selfdir+"initial", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'initial')
    updated = add_bundle_dir(selfdir+"updated", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'updated')
    compile_bundles(@vespa.nodeproxies.values.first)

    # initial deployment
    initial_output = deploy_and_activate(initial)
    session_initial = get_generation(initial_output).to_i
    start

    #vespa.adminserver.execute("vespa-logctl configproxy:com.yahoo.vespa.filedistribution debug=on", :exceptiononfailure => false)
    #vespa.adminserver.execute("vespa-logctl configproxy:com.yahoo.vespa.config.proxy.filedistribution.FileDistributionRpcServer debug=on", :exceptiononfailure => false)

    # deployment with updated bundle
    updated_output = deploy_do_not_activate(updated)
    session_updated_bundle = get_generation_from_prepare(updated_output).to_i

    start_session = session_updated_bundle + 1
    # Deploy several times without activating (simulates internal redeployment with many model versions)
    start_session.upto(start_session + 5) { |session|
      deploy_from_active_app_do_not_activate
      puts "Preparing #{session}"
      deploy_prepare(session)
    }

    # Activate session with updated bundle
    deploy_activate(session_updated_bundle)

    @container = vespa.container.values.first
    # Now, check that file distribution distributed the updated bundle (i.e. it got the expected config generation)
    @container.wait_for_config_generation(session_updated_bundle)
  end

  def deploy_and_activate(bundle)
    deploy({:bundles => [bundle]})
  end

  def deploy_do_not_activate(bundle)
    deploy({:bundles => [bundle], :no_activate => true, :skip_create_model => true})
  end

  def deploy_from_active_app_do_not_activate
    # TODO: Below is an attempt to make this work on just one host, need to look into why it failed
    configserver = (configserverhostlist.length > 0 ? configserverhostlist[0] : vespa.nodeproxies.first[0])
    from_url = "http://#{configserver}:19071/application/v2/tenant/#{@tenant_name}/application/#{@application_name}/environment/prod/region/default/instance/default"
    deploy({:from_url => from_url, :no_activate => true, :skip_create_model => true})
  end

  def deploy_prepare(session_id)
    deploy_with_command("prepare", session_id)
  end

  def deploy_activate(session_id)
    deploy_with_command("activate", session_id)
  end

  def deploy_with_command(command, session_id)
    node = vespa.adminserver
    execute(node, "vespa-deploy -e #{@tenant_name} -a #{application_name} #{command} #{session_id}")
  end

  def get_generation_from_prepare(deploy_output)
    deploy_output =~ /Session (\d+) for tenant/i
    return $1;
  end

  def teardown
    stop
  end

end
