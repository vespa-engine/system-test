# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'app_generator/search_app'
require 'environment'

class VespaGetConfig < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Tests Cloud Config System tools")
    app_gen = SearchApp.new.sd(SEARCH_DATA+"music.sd")
    deploy_app(app_gen)
    start
  end

  def test_getvespaconfig
    getconfig = "#{Environment.instance.vespa_home}/bin/vespa-get-config"
    (exitcode, out) = execute(vespa.adminserver, "#{getconfig} -n cloud.config.log.logd -i \"\" -w 10")
    assert_equal(exitcode, 0)
    (exitcode, out) = execute(vespa.adminserver, "#{getconfig} -n unknown -i \"\" -w 10 -p 19070")
    assert_equal(exitcode, 1)
    assert_match(/error 100001: Failed request \(Unknown config definition name=config.unknown,configId=\) from Connection .*/, out)
  end

  def teardown
    stop
  end

end
