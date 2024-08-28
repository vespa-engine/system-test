# Copyright Vespa.ai. All rights reserved.
require 'cloudconfig_test'

class Corruption < CloudConfigTest
  
  TENANT_A = "a"
  TENANT_B = "b"
  
  def can_share_configservers?
    true
  end

  def initialize(*args)
    super(*args)
    @num_hosts = 2
  end

  def setup
    super
    @configserver = configserverhostlist[0]
  end
      
  def WIPtest_corruption_isolation
    set_description("Corrupt app and tenant data should not affect others")
    create_tenants_and_wait([TENANT_A, TENANT_B], @configserver)
  end
  
  def teardown
    stop
    delete_tenant_and_its_applications(@hostname, TENANT_A)
    delete_tenant_and_its_applications(@hostname, TENANT_B)
  end
end
