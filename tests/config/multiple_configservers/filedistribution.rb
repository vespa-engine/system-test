# coding: utf-8
# Copyright Vespa.ai. All rights reserved.

require 'config_test'
require 'app_generator/container_app'
require 'environment'

class FileDistributionWithMultipleConfigServers < CloudConfigTest

  def initialize(*args)
    super(*args)
    @num_hosts = 5
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
    deploy_test_app

    # Make sure there are no files from other tests lying around
    execute_on_all_configservers("find #{Environment.instance.vespa_home}/var/db/vespa/filedistribution -mindepth 1 -type d | xargs rm -rf")

    request_unknown_file_reference

    add_bundle_dir(File.expand_path(selfdir), @bundle_name)
    deploy_test_app_with_searcher
    start
    verífy_file_reference_exists_on_all_servers
  end

  def deploy_test_app_with_searcher
    deploy_test_app(true)
  end

  def deploy_test_app(add_searcher=nil)
    if add_searcher
      puts "Deploying app with searcher"
      app = ContainerApp.new.
              container(Container.new.search(Searching.new.
                                               chain(Chain.new.add(
                                                       Searcher.new("com.yahoo.vespatest.ExtraHitSearcher")))).
                          node({ :hostalias => "node4" }).
                          node({ :hostalias => "node5" }))
    else
      puts "Deploying simple app"
      app = ContainerApp.new.
              container(Container.new.search(Searching.new).
                          node({ :hostalias => "node4" }).
                          node({ :hostalias => "node5" }))
    end

    app = app.configserver("node1").num_hosts(@num_hosts)
    if @num_hosts >= 3
      app = app.configserver("node2").
              configserver("node3")
    end

    deploy_app(app)
  end

  def request_unknown_file_reference
    # Ask for a non-existing file reference
    execute_on_all_configservers("vespa-rpc-invoke tcp/localhost:19070 filedistribution.serveFile s:277c8dcff14e84f1ec55c88395a365388375de34 i:0", :exceptiononfailure => false)
    # Sleep to make sure we have had repeated requests (we want to test that we don't end up using all resources getting a file that does not exist)
    sleep 90
  end

  def execute_on_all_configservers(command, params={})
    vespa.configservers.each_value do |node|
      node.execute(command, params)
    end
  end

  def verífy_file_reference_exists_on_all_servers
    iterations = 0
    loop do
      iterations = iterations + 1
      begin
        execute_on_all_configservers("ls -lR #{Environment.instance.vespa_home}/var/db/vespa/filedistribution | grep #{@bundle_name}")
        break # Success!
      rescue ExecuteError => e
        puts "Getting file reference failed (iteration #{iterations}), will retry"
      end
      sleep 5
      break if iterations > 20
    end
  end

  def teardown
    stop
  end

end
