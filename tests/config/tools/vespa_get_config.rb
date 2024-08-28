# Copyright Vespa.ai. All rights reserved.
require 'config_test'
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
    (exitcode, out) = vespa.adminserver.execute("#{getconfig} -n cloud.config.log.logd -i \"\" -w 10", { :exitcode => true })
    assert_equal(exitcode.to_i, 0)
    (exitcode, out) = vespa.adminserver.execute("#{getconfig} -n unknown -i \"\" -w 10 -p 19070", { :exitcode => true, :stderr => true })
    assert_equal(exitcode.to_i, 1)
    assert_match(/error 100001: Failed request \(Unknown config definition name=config.unknown,configId=\) from Connection .*/, out)
  end

  def teardown
    stop
  end

end
