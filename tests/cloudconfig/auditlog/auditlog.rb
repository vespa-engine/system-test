# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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

  def nightly?
    true
  end

  def test_audit_log_v2
    gen = get_generation(deploy("#{selfdir}/../deploy/base"))
    sleep 6 # The access log might have up to 5s delay.
    assert_log_lines("/application/v2/tenant/default/session", gen)
  end

  def assert_log_lines(base_url, gen)
    file_content = get_audit_log(@node)
    assert_match(/\"POST #{base_url} HTTP\/1.1\" 200/, file_content)
    assert_match(/\"PUT #{base_url}\/#{gen}\/prepared.* HTTP\/1.1\" 200/, file_content)
    assert_match(/\"PUT #{base_url}\/#{gen}\/active.* HTTP\/1.1\" 200/, file_content)
  end

  def get_audit_log(node)
    node.execute("sync")
    node.readfile("#{Environment.instance.vespa_home}/logs/vespa/configserver/access.log")
  end

  def teardown
    stop
    @node.stop_base if @node
    puts "Stopping configserver"
    @node.stop_configserver if @node
  end
end
