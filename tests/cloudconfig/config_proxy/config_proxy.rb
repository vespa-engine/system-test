# Copyright Vespa.ai. All rights reserved.
require 'cloudconfig_test'
require 'search_test'
require 'search_test'
require 'environment'

class ConfigProxy < CloudConfigTest

  CONFIG_JAR = "#{Environment.instance.vespa_home}/lib/jars/config-with-dependencies.jar"
  CONFIG_SOURCE = "export VESPA_CONFIG_SOURCES=localhost:19070"

  def initialize(*args)
    super(*args)
  end

  def setup
    set_description("Tests that the config proxy returns correct config, test mode switching and test the different modes")
    set_owner("musum")
    @route_count = 7
  end

  def timeout_seconds
    1400
  end

  def deploy_app_with_routes
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
      cluster_name("music").
      routingtable(RoutingTable.new.
        add(Hop.new("search-hop", "[Content:cluster=music]")).
        add(Route.new("new-route-1", "search-hop"))))
  end

  def deploy_app_with_one_extra_route
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
      cluster_name("music").
      routingtable(RoutingTable.new.
        add(Hop.new("search-hop", "[Content:cluster=music]")).
        add(Route.new("new-route-1", "search-hop")).
        add(Route.new("new-route-2", "search-hop"))))
  end

  # Test that switching to memorycache mode and back to default mode works
  def test_mode_switching
    add_bundle_dir(selfdir+"simplebundle", "simplebundle")
    deploy_app_with_routes
    start
    # feed to make sure we have documentmanager config in proxy cache
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json")
    node = vespa.adminserver
    assert_equal("default\n", get_proxy_mode(node))

    assert_equal("0\nsuccess\n", set_proxy_mode(node, "memorycache"))
    assert_equal("memorycache\n", get_proxy_mode(node))

    # all operations below gets config from cache in config proxy
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json")
    #restart qrserver, which will get config from cache in config proxy
    restart_qrserver(vespa, 10, "query=sddocname:music&nocache")

    # try setting to invalid mode
    assert_equal("1\nUnrecognized mode 'invalid' supplied. Legal modes are '[memorycache, default]'\n", set_proxy_mode(node, "invalid"))

    # set back to default mode
    assert_equal("0\nsuccess\n", set_proxy_mode(node, "default"))

    # Check that applications now pick up new config from server
    command_app_1 = "cd #{dirs.tmpdir}; #{get_java_command}"
    out_file_1 = "#{dirs.tmpdir}app1.out"

    add_bundle_dir(selfdir+"simplebundle", "simplebundle")

    # start application that subscribes to the same config
    threadlist = []
    threadlist << Thread.new { vespa.adminserver.execute("#{command_app_1} #{out_file_1}") }

    assert_config(@route_count, out_file_1)

    deploy_app_and_assert(:deploy_app_with_one_extra_route, @route_count + 1, [out_file_1])
  end

  # Test that we get new config when multiple applications subscribe to the same config
  # (bypassing config proxy)
  # Also test that we get config when there is a new generation of config (the response
  # from the server will be empty, but the config proxy will return the previous config payload)
  def test_multiple_subcribers_no_proxy
    command = "cd #{dirs.tmpdir}; #{CONFIG_SOURCE}; #{get_java_command}"
    multiple_subcribers_common(command, command, false)
  end

  # Test that we get new config when multiple applications subscribe to the same config
  # (one using config proxy, the other getting config directly from the config server)
  # Also test that we get config when there is a new generation of config (the response
  # from the server will be empty, but the config proxy will return the previous config payload)
  def test_multiple_subcribers_with_proxy
    @valgrind = false
    command_app_1 = "cd #{dirs.tmpdir}; #{get_java_command('client1')}"
    command_app_2 = "cd #{dirs.tmpdir}; #{CONFIG_SOURCE}; #{get_java_command('client2')}"
    multiple_subcribers_common(command_app_1, command_app_2)
    # Request a non-existing config and check that other subscribers work and can be reconfigured afterwards
    (exitcode, out) = execute(vespa.adminserver, "vespa-get-config -n foo -v 1 -i habla")
    assert_equal(exitcode, 1)

    out_file_1 = "#{dirs.tmpdir}app1.out"
    out_file_2 = "#{dirs.tmpdir}app2.out"
    out_files = [out_file_1, out_file_2]

    assert_config(@route_count + 1, out_file_1)
    assert_config(@route_count + 1, out_file_2)

    config_generation = get_generation(deploy_app_and_assert(:deploy_app_with_routes, @route_count, out_files)).to_i
    wait_for_reconfig(config_generation)
    # One more time to check that it works with new generation, unchanged config
    config_generation = get_generation(deploy_app_and_assert(:deploy_app_with_routes, @route_count, out_files)).to_i
    wait_for_reconfig(config_generation)
  end

  # Tests that getting an error upstream (e.g. UNKNOWN_DEFINITION) makes the
  # config proxy stop subscribing to this config (and logging error message is not excessive)
  # Also checks that getting this config after deploying an application where it is
  # defined works as expected
  def test_unknown_config_is_not_subscribed_to_forever
    deploy_app(CloudconfigApp.new)
    start
    node = vespa.adminserver
    assert_equal(19080, getvespaconfig('cloud.config.log.logd', 'client')['logserver']['rpcport'])
    out = node.execute("vespa-get-config -n bar.baz.extra -i client -j", :exceptiononfailure => false, :stderr => true)
    assert_equal("error 103: (RPC) Invocation timed out\n", out)

    # Wait until subscriber has been closed
    wait_for_log_matches(/Subscribe for 'name=bar.baz.extra,configId=client,\h{32}' failed, closing subscriber/, 1, 60)

    count = find_config_proxy_log_warnings()
    assert(count < 15, "expected less than 15 warnings in log, but was #{count}")

    add_bundle_dir(selfdir + "simplebundle", "simplebundle")
    deploy_app(CloudconfigApp.new.
               config(ConfigOverride.new("bar.baz.extra").
                      add("quux", "test")))
    assert_equal('test', getvespaconfig('bar.baz.extra', 'client')['quux'])
  end

  def find_config_proxy_log_warnings
    log = ""
    vespa.logserver.get_vespalog do |buf|
      log += buf
    end
    loglines = log.split(/\n/)

    count = 0
    loglines.each { |line|
      fields = line.split(/\t/)
      if fields[3] == "configproxy" && fields[5] == "warning"
        count = count + 1
      end
    }
    count
  end

  # Test that we get new config when multiple applications subscribe to the same config
  # (bypassing config proxy)
  def multiple_subcribers_common(command_app_1, command_app_2, start_base=true)
    add_bundle_dir(selfdir+"simplebundle", "simplebundle")
    # deploy new app with 3 routes
    deploy_output = deploy_app_with_routes
    if (start_base)
      start
    end

    out_file_1 = "#{dirs.tmpdir}app1.out"
    out_file_2 = "#{dirs.tmpdir}app2.out"
    out_files = [out_file_1, out_file_2]

    # start 2 applications that subscribe to the same config
    threadlist = []
    threadlist << Thread.new { vespa.adminserver.execute("#{command_app_1} #{out_file_1} client1") }
    threadlist << Thread.new { vespa.adminserver.execute("#{command_app_2} #{out_file_2} client2") }

    gen = get_generation(deploy_output)
    assert_config(@route_count, out_file_1, gen)
    assert_config(@route_count, out_file_2, gen)

    config_generation = get_generation(deploy_app_and_assert(:deploy_app_with_routes, @route_count, out_files)).to_i
    if (start_base)
      wait_for_reconfig(config_generation)
    end
    config_generation = get_generation(deploy_app_and_assert(:deploy_app_with_one_extra_route, @route_count + 1, out_files)).to_i
    if (start_base)
      wait_for_reconfig(config_generation)
    end
    # One more time to check that it works with new generation, unchanged config
    config_generation = get_generation(deploy_app_and_assert(:deploy_app_with_one_extra_route, @route_count + 1, out_files)).to_i
    if (start_base)
      wait_for_reconfig(config_generation)
    end
  end

  def get_file_contents(out_file)
    vespa.adminserver.readfile(out_file)
  end

  def assert_config(expected_value, file, expected_generation=nil)
    expected_value = expected_value.to_s
    if expected_generation
      expected_generation = expected_generation.to_s
    end
    max_tries = 30
    i = 0
    ok = false
    val = nil
    gen = nil
    while (!ok && i < max_tries)
      puts "i=#{i}, ok=#{ok}"
      i = i + 1
      content = get_file_contents(file)
      if content
        puts "File content:#{content}"
        (val, gen) = content.split("\n")
      end
      if (val == expected_value and (!expected_generation or (gen == expected_generation)))
        ok = true
      else
        sleep 1
      end
    end
    if expected_generation
      assert_equal(expected_generation, gen)
    end
    assert_equal(expected_value, val)
  end

  def get_proxy_mode(node)
    node.execute("vespa-configproxy-cmd -m getmode", :exceptiononfailure => false)
  end

  def set_proxy_mode(node, mode)
    node.execute("vespa-configproxy-cmd -m setmode #{mode}", :exceptiononfailure => false)
  end

  def find_config_proxy_pid(node)
    pscommand = node.execute("ps axuww", :noecho => true).strip
    lines = pscommand.split("\n")
    pid = nil
    lines.each {|line|
      if line.include? "ProxyServer"
        if !line.include? "runserver"
#          puts "#{line}"
          pid = line.split("\s")[1]
          puts "pid=#{pid}"
        end
      end
    }
    pid
  end

  def restart_qrserver(vespa, hits, query)
    vespa.container.values.first.stop
    vespa.container.values.first.start
    wait_for_hitcount(query, hits)
  end

  def start_config_server(node)
    node.start_configserver
    node.ping_configserver    
  end

  def stop_config_server(node)
    node.stop_configserver({:keep_everything => true})    
  end

  def teardown
    if vespa and vespa.adminserver
      @dirty_environment_settings = true
      vespa.adminserver.kill_process("AppService")
      vespa.adminserver.execute("rm -f #{Environment.instance.vespa_home}/var/vespa/cache/config/*")
    end
    stop
  end

  def get_java_command(service_name="client1", debug=false)
    debug_options = debug ? " -Dvespa.service.name=#{service_name} -Dvespa.log.level=error,warning,info,debug -Dvespa.log.target=file:#{Environment.instance.vespa_home}/logs/vespa/vespa.log" : ""
    java_command = "java -Xms16m -Xmx64m -cp #{CONFIG_JAR}:bundles/simplebundle-1.0-deploy.jar #{debug_options} com.yahoo.vespa.configtestapp.AppService"
  end

  # Check if config content (number of routes) and config generation is as expected)
  def deploy_app_and_assert(deploy_method, route_count, files)
    deploy_output = self.send(deploy_method)
    gen = get_generation(deploy_output)
    files.each do |file|
      assert_config(route_count, file, gen)
    end
    deploy_output
  end

end
