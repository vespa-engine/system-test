# Copyright Vespa.ai. All rights reserved.
require 'config_test'

class ZkCtl < CloudConfigTest

  def setup
    set_owner("musum")
    set_description("Tests vespa-zkctl tool")
  end

  def test_zkctl
    deploy(selfdir+"base")
    assert_match(/tenants.*/, vespa.adminserver.execute("vespa-zkctl ls /config/v2"))
  end

  def teardown
    stop
  end

end
