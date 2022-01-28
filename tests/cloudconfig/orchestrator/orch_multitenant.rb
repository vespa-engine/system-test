require 'search_container_test'

class OrchestratorMultiTenantTest < SearchContainerTest

  def initialize(*args)
    super(*args)
    @num_hosts = 6
  end

  def timeout_seconds
    1800
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def mtappdir(appid="0")
    selfdir + 'multitenant/app' + appid
  end

  def setup
    set_owner("arnej")
    set_description("Test multiple apps in a multi-tenant (hosted vespa emulation) setup")
    @valgrind = false

    @cfgsrvnode = nil
    @did_deploy1 = nil
    @did_deploy2 = nil
    @did_deploy3 = nil
  end

  def teardown
    if cmd_args[:nostop]
      puts "Skipping stop and clean from teardown"
    else
      if @did_deploy3
        puts "CLEANUP 3"
        deploy(mtappdir('3'), nil, :tenant => 'quux')
        if @did_deploy1 || @did_deploy2
          @vespa.stop_base
          @vespa.clean
        end
      end
      if @did_deploy2
        puts "CLEANUP 2"
        deploy(mtappdir('2'), nil, :tenant => 'nalle')
        if @did_deploy1
          @vespa.stop_base
          @vespa.clean
        end
      end
      if @did_deploy1
        puts "CLEANUP 1"
        deploy(mtappdir('1'), nil, :tenant => 'huff')
      end
    end
    stop
  end

  def orch_uri(path)
    node = @cfgsrvnode
    return URI("http://#{node.hostname}:19071/orchestrator/v1/#{path}")
  end

  def orch_get(path)
    uri = orch_uri(path)
    https_client.get(uri.host, uri.port, uri.path)
  end

  def check_no_down(instance_json)
    return false unless instance_json
    return false unless instance_json['applicationInstance']
    srv_cluster = instance_json['applicationInstance']['serviceClusters']
    return false unless srv_cluster
    srv_cluster.each do |cv|
      if cv['serviceInstances']
        cv['serviceInstances'].each do |si|
          info = si['serviceStatusInfo']
          raise "serviceStatusInfo missing for service: #{si}" unless info
          status = info['serviceStatus']
          case status
          when 'DOWN'
            puts "service instance down: #{si}"
            return false
          when 'NOT_CHECKED', 'UP'
          else
            raise "Unknown service status in service: #{si}"
          end
        end
      end
    end
    return true
  end

  def wait_no_down(instanceid="default:default:prod:default:default")
    60.times do
      resp = orch_get("instances/#{instanceid}")
      return if check_no_down(get_json(resp))
      puts "some service instance is DOWN, wait a bit"
      sleep 1
    end
  end

  def no_test_setup_only
    deploy(mtappdir '0')
    @cfgsrvnode = @vespa.configservers.values.first
    @vespa.stop_configservers
    override_environment_setting(@cfgsrvnode, "VESPA_CONFIGSERVER_MULTITENANT", "true")
    puts "multitenant configserver on: #{@cfgsrvnode.hostname}"

    deploy(mtappdir('1'), nil, :tenant => 'huff')

    # subsequent deploys will overwrite references in @vespa (model)
    # so save any references we need first:
    a1 = @vespa.adminserver
    q1 = @vespa.qrserver["0"]
    assert(a1)
    assert(q1)
    @did_deploy1 = true

    deploy(mtappdir('2'), nil, :tenant => 'nalle')
    a2 = @vespa.adminserver
    q2 = @vespa.qrserver["0"]
    assert(q2)
    @did_deploy2 = true

    deploy(mtappdir('3'), nil, :tenant => 'quux')
    a3 = @vespa.adminserver
    q3 = @vespa.qrserver["0"]
    assert(q3)
    @did_deploy3 = true

    start
    puts "cluster 1 admin on: #{a1.hostname}"
    puts "cluster 2 admin on: #{a2.hostname}"
    puts "cluster 3 admin on: #{a3.hostname}"

    wait_no_down("huff:default:prod:default:default")
    wait_no_down("nalle:default:prod:default:default")
    wait_no_down("quux:default:prod:default:default")
    wait_no_down("hosted-vespa:zone-config-servers")

    resp = orch_get('instances/')
    assert(resp)
    puts "response body 'instances/': >>> #{resp.body} <<<"

    a1.feed(:file => selfdir + "feeds/music.xml")
    a1.feed(:file => selfdir + "feeds/other.xml")

    a2.feed(:file => selfdir + "feeds/bimbam.xml")
    a3.feed(:file => selfdir + "feeds/foobar.xml")

    @vespa.qrserver["0"] = q1
    assert_hitcount("query=sddocname:music", 9)
    assert_hitcount("query=sddocname:other", 9)

    assert_hitcount("bar", 14)
    assert_hitcount("barfoo", 1)

    @vespa.qrserver["0"] = q2
    assert_hitcount("bar", 9)
    assert_hitcount("barfoo", 0)

    @vespa.qrserver["0"] = q3
    assert_hitcount("bar", 1)
    assert_hitcount("barfoo", 3)
  end

end
