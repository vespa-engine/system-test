# Copyright Vespa.ai. All rights reserved.
require 'config_test'
require 'uri'
require 'net/http'

class OrchestratorContainerClusterTest < ConfigTest

  UP = "NO_REMARKS"
  DOWN = "ALLOWED_TO_BE_DOWN"

  def initialize(*args)
    super(*args)
    @num_hosts = 4
  end

  def can_share_configservers?
    false
  end

  def setup
    set_owner("andreer")
    set_description("Test orchestrator with a simple container cluster")
  end

  def teardown
    stop
  end

  def orch_uri(path)
    node = @vespa.configservers.values.first
    return URI("http://#{node.hostname}:19071/orchestrator/v1/#{path}")
  end

  def process_response(response)
    puts "HTTP response code: #{response.code}"
    puts "HTTP response body: \n>>>>> #{response.body} <<<<<"
    response
  end

  def orch_get(path)
    uri = orch_uri(path)
    process_response(https_client.get(uri.host, uri.port, uri.path))
  end

  def orch_suspend(host)
    uri = orch_uri("hosts/#{host}/suspended")
    process_response(https_client.put(uri.host, uri.port, uri.path, nil))
  end

  def orch_resume(host)
    uri = orch_uri("hosts/#{host}/suspended")
    process_response(https_client.delete(uri.host, uri.port, uri.path))
  end

  def orch_suspend_until_no_conflict(host)
    time_end = Time.now.to_i + 600
    loop do
      response = orch_suspend(host)
      return response if response.code.to_i != 409
      return response unless Time.now.to_i < time_end
      puts "Failed to suspend #{host}, will retry in a short while"
      sleep(0.5)
    end
  end

  def orch_resume_until_no_conflict(host)
    time_end = Time.now.to_i + 600
    loop do
      response = orch_resume(host)
      return response if response.code.to_i != 409
      return response unless Time.now.to_i < time_end
      puts "Failed to resume #{host}, will retry in a short while"
      sleep(0.5)
    end
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

  def assert_instance(expected_host_infos, instanceid="default:default:prod:default:default")
    resp = orch_get("instances/#{instanceid}")
    assert_response_code(resp)
    host_infos = get_json(resp)["hostInfos"]
    actual_host_infos = host_infos.each { |host, info| host_infos[host] = info["hostStatus"] }
    assert(expected_host_infos == actual_host_infos, "#{expected_host_infos.to_s} is not equal to #{actual_host_infos.to_s}")
  end

  def assert_hosts(hosts, state)
    hosts.each do |host|
      assert_host(host, state)
    end
  end

  def assert_host(host, state)
    resp = orch_get("hosts/#{host}")
    assert_response_code(resp)
    assert_json_contains_field_value(get_json(resp), "state", state)
  end

  def test_orchestrator_answers_ok
    deploy(selfdir + 'container-app')
    start
    wait_no_down

    confnode = @vespa.configservers.values.first.hostname
    containerA = @vespa.container["mycc/0"].hostname
    containerB = @vespa.container["mycc/1"].hostname

    resp = orch_get("instances/")
    assert_response_code(resp)
    assert_equal(JSON.parse('["default:default:prod:default:default"]'), get_json(resp))
    
    all_up = {confnode => UP, containerA => UP, containerB => UP }
    assert_instance(all_up)

    assert_host(containerA, UP)
    assert_host(containerB, UP)
    
    assert_response_code(orch_suspend(containerA))

    a_allowed_down = {confnode => UP, containerA => DOWN , containerB => UP}
    assert_instance(a_allowed_down)

    resp = orch_suspend(containerB)
    assert_response_code(resp, 409)
    assert_json_contains_field(get_json(resp), "reason")

    assert_host(containerA, DOWN)
    assert_host(containerB, UP)
    
    assert_response_code(orch_resume(containerA))

    assert_host(containerA, UP)
    
    assert_instance(all_up)

    assert_response_code(orch_suspend(containerB))

    b_allowed_down = {confnode => UP, containerA => UP , containerB => DOWN }
    assert_instance(b_allowed_down)

    assert_response_code(orch_resume(containerB))

    assert_instance(all_up)
  end

  def start_content_app
    deploy(selfdir + 'content-app')
    start
    wait_no_down
    feedfile(selfdir + 'music-data.json')

    configServer = @vespa.configservers.values.first.hostname
    @contentC = @vespa.content_node("music", 0).hostname
    @contentD = @vespa.content_node("music", 1).hostname
    @contentE = @vespa.content_node("music", 2).hostname

    resp = orch_get("instances/")
    assert_response_code(resp)
    assert_equal(JSON.parse('["default:default:prod:default:default"]'), get_json(resp))

    @all_up = { configServer => UP, @contentC => UP, @contentD => UP, @contentE => UP}
    assert_instance(@all_up)
    assert_hosts(@all_up.keys, UP)
  end

  def test_restart_of_content_node
    # A restart involves:
    # 1. Ask permisssion to suspend until successful, then...
    # 2. No other should be allowed to suspend
    # 3. Restart of service
    # 4. Resume services should eventually succeed

    start_content_app

    assert_response_code(orch_suspend_until_no_conflict(@contentC))

    c_allowed_down = @all_up.clone
    c_allowed_down[@contentC] = DOWN
    assert_instance(c_allowed_down)

    assert_host(@contentC, DOWN)
    assert_host(@contentD, UP)
    assert_host(@contentE, UP)
    
    assert_response_code(orch_suspend(@contentD), 409)

    @vespa.stop_content_node("music", 0)
    wait_until_up = false
    @vespa.start_content_node("music", 0, 60, wait_until_up)

    assert_response_code(orch_resume_until_no_conflict(@contentC))

    assert_host(@contentC, UP)

    assert_instance(@all_up)
  end

  def test_upgrade_of_downed_node
    # We'll simulate an upgrade of a downed node in the following way:
    # 1. Down the services on the node to simulate crash/unavailability
    # 2. No other should be allowed to suspend
    # 3. Ask permission to suspend that host, should be successful
    # 4. Start services, simulating the upgraded services fixes the problem
    # 5. Resume services should eventually succeed

    start_content_app
    stop_wait_timeout = 600
    @vespa.stop_content_node("music", 0, stop_wait_timeout, 'd')

    # Wait until stopped node is allowed suspension.  The first suspend may not
    # complete without timeouts (observed with slow system test nodes),
    # therefore retry until success.
    time_end = Time.now.to_i + 600
    response = nil
    loop do
      assert_response_code(orch_suspend(@contentD), 409)
      assert_response_code(orch_suspend(@contentE), 409)

      response = orch_suspend(@contentC)
      break unless response.code.to_i == 409
      break unless Time.now.to_i < time_end
      puts "Failed to suspend #{@contentC}, will retry in a short while"
      sleep(1.0)
    end
    assert_response_code(response)

    c_allowed_down = @all_up.clone
    c_allowed_down[@contentC] = DOWN
    assert_instance(c_allowed_down)

    assert_host(@contentC, DOWN)
    assert_host(@contentD, UP)
    assert_host(@contentE, UP)
    
    wait_until_up = false
    @vespa.start_content_node("music", 0, 60, wait_until_up)

    assert_response_code(orch_resume_until_no_conflict(@contentC))

    assert_host(@contentC, UP)

    assert_instance(@all_up)
  end
end
