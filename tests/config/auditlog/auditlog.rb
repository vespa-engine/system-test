# Copyright Vespa.ai. All rights reserved.
require 'cloudconfig_test'
require 'environment'

class AuditLog < CloudConfigTest

  def setup
    super
    set_owner("musum")
    set_description("Tests that audit logging for config server REST API works")
    @node = @vespa.nodeproxies.first[1]
  end

  def initialize(*args)
    super(*args)
  end

  def test_audit_log_v2
    gen = get_generation(deploy("#{selfdir}/../deploy/base"))
    sleep 6 # The access log might have up to 5s delay.
    assert_log_lines("/application/v2/tenant/default/session", gen)
  end

  def assert_log_lines(base_url, gen)
    assert_log_line_matches("POST", base_url, 200)
    assert_log_line_matches("PUT", "#{base_url}\/#{gen}\/prepared", 200)
    assert_log_line_matches("PUT", "#{base_url}\/#{gen}\/active", 200)
  end

  def assert_log_line_matches(method, uri, response_code)
    file_content = get_audit_log(@node)
    match = false
    file_content.split("\n").each do |line|
      json = JSON.parse(line)
      match = (method == json['method'] and uri == json['uri'] and response_code.to_s == json['code'])
      break if match
    end
    match
  end

  def get_audit_log(node)
    node.execute("sync")
    node.readfile("#{Environment.instance.vespa_home}/logs/vespa/configserver/access-json.log")
  end

  def teardown
    stop
    @node.stop_base if @node
    @node.stop_configserver if @node
  end
end
