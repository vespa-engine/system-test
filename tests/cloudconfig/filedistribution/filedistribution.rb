require 'cloudconfig_test'
require 'json'
require 'app_generator/container_app'
require 'app_generator/search_app'

# Note: 2 hosts are needed. If you want to run this by yourself you need to add "--configserverhost some_other_host"
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

    deploy({:bundles => [bundle]})
    start
  end

  def deploy(params)
    deploy_app(create_app(), params)
  end

  def create_app
    ContainerApp.new.
      container(Container.new.
                handler(Handler.new("com.yahoo.vespatest.VersionHandler").
                        bundle("com.yahoo.vespatest.ExtraHitSearcher").
                        binding("http://*/Version")))
  end

  def teardown
    stop
  end

end
