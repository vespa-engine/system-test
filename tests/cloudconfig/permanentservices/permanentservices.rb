# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'search_test'
require 'environment'

class PermanentServices < CloudConfigTest

  def initialize(*args)
    super(*args)
    @use_shared_configservers = false
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def setup
    set_owner("musum")
    set_description("Tests that we can add permanent services that are always part of a config model")
    @node = vespa.nodeproxies.first[1]
  end

  def test_permanent_ping
    save_configserver_app(@node)
    @node.copy("#{selfdir}/permanent-services.xml", Environment.instance.vespa_home + "/conf/configserver-app/")
    deploy_app(CloudconfigApp.new)
    start
    wait_for_atleast_log_matches(Regexp.compile("vmstat\\s.*\\s.*procs -----------memory----------"), 1)
  end

  def teardown
    restore_configserver_app(@node)
    stop
  end
end
