require 'cloudconfig_test'
require 'search_test'
require 'environment'

class FileDistributionMultipleConfigServers < CloudConfigTest

  def initialize(*args)
    super(*args)
    @num_hosts = 3
    @bundle_name = "com.yahoo.vespatest.ExtraHitSearcher"
  end

  def setup
    @valgrind = false
    set_description("Tests that file distribution works when using multiple configservers. " +
                    "Files should be distributed to all config servers so we have " +
                    "redundancy if one or more of them go down")
    set_owner("musum")
  end

  def test_file_distribution
    # First deploy to setup so that we have node proxies
    deploy_app(SearchApp.new.
               sd(selfdir + "banana.sd").
               num_hosts(3).
               configserver("node1").
               configserver("node2").
               configserver("node3"))

    # Temp debug logging
    execute_on_all_configservers("vespa-logctl configserver:com.yahoo.vespa.filedistribution debug=on")
    execute_on_all_configservers("vespa-logctl configserver:com.yahoo.vespa.config.server.filedistribution debug=on")

    # Make sure there are no files from other tests lying around
    execute_on_all_configservers("find #{Environment.instance.vespa_home}/var/db/vespa/filedistribution -mindepth 1 -type d | xargs rm -rf")

    # Ask for a non-existing file reference
    execute_on_all_configservers("vespa-rpc-invoke tcp/localhost:19070 filedistribution.serveFile s:277c8dcff14e84f1ec55c88395a365388375de34 i:0", :exceptiononfailure => false)
    # Sleep to make sure we have had repeated requests (we want to test that we don't end up using all resources getting a file that does not exist)
    sleep 90

    add_bundle_dir(File.expand_path(selfdir), @bundle_name)
    deploy_test_app(selfdir + "banana.sd")
    start
    feed_and_wait_for_docs("banana", 3, :file => selfdir+"bananafeed.xml")
    execute_on_all_configservers("ls -lR #{Environment.instance.vespa_home}/var/db/vespa/filedistribution | grep #{@bundle_name}")
  end

  def deploy_test_app(sd)
    deploy_app(SearchApp.new.
               sd(sd).
               search_chain(SearchChain.new.
                            add(Searcher.new("com.yahoo.vespatest.ExtraHitSearcher"))).
               num_hosts(3).
               configserver("node1").
               configserver("node2").
               configserver("node3"))
  end

  def execute_on_all_configservers(command, params={})
    vespa.configservers.each_value do |node|
      node.execute(command, params)
    end
  end

  def teardown
    stop
  end

end
