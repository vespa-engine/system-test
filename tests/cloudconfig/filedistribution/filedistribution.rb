# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'cloudconfig_test'
require 'json'
require 'app_generator/container_app'
require 'app_generator/search_app'

# Note: 2 hosts are needed (one for config server, one for vespa app).
# If you want to run this manually you need to add "--configserverhost some_other_host"
class FileDistributionBasic < CloudConfigTest

  def can_share_configservers?(method_name=nil)
    true
  end

  def setup
    set_owner("musum")
    set_description("Tests file distribution basics")
    @valgrind = false
  end

  def test_filedistribution
    bundle = add_bundle_dir(selfdir + "initial", "com.yahoo.vespatest.ExtraHitSearcher", :name => 'initial')
    compile_bundles(@vespa.nodeproxies.values.first)

    deploy(selfdir+"app", nil, {:bundles => [bundle]})
    start
  end

  def teardown
    stop
  end

end
