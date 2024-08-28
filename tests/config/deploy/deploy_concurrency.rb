require 'config_test'
require 'application_v2_api'
require 'json'

class DeployConcurrency < ConfigTest

include ApplicationV2Api

  def can_share_configservers?
    true
  end

  def setup
    set_owner("musum")
    set_description("Tests concurrent deployments for the same tenant")
    @node = @vespa.nodeproxies.first[1]
    @hostname = @vespa.nodeproxies.first[0]
    @session_id=nil

    deploy_app(ConfigApp.new)
    @configserver = configserverhostlist[0]
  end

  def test_deploy_concurrently_for_same_tenant
    threads = []
    1.upto(2) { |i|
      threads << Thread.new(i) { |id|
        application_name = "app_#{id}"
        puts "Deploying app #{application_name}"
        result = deploy_app_v2_api("#{CLOUDCONFIG_DEPLOY_APPS}/app_a", @configserver, @tenant_name, application_name)
        assert_equal(200, result.code.to_i, result.body)
      }
    }

    threads.each do |thread|
      thread.join
    end
  end

  def teardown
    stop
    @node.stop_base if @node
    puts "Stopping configserver"
    @node.stop_configserver if @node
  end
end
