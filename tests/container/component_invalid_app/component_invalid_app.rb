# Copyright Vespa.ai. All rights reserved.
require 'container_test'
require 'app_generator/container_app'

class ComponentInvalidApp < ContainerTest

  # No point in running standalone, as it does not support reconfig
  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

  def timeout_seconds
    return 900
  end

  def setup
    set_owner("gjoranv")
    set_description("Verifies that the previously deployed good application remains active when the new application fails during reconfiguration.")
    @app_failures = 0
  end

  def test_bootstrap_reconfig_works_after_failed_reconfig
    set_expected_logged(/Error constructing 'com.yahoo.test.Fail2Handler'/)

    ok1   = add_bundle(selfdir + "Ok1Handler.java", :name => "Ok1Handler")
    fail2 = add_bundle(selfdir + "Fail2Handler.java", :name => "Fail2Handler")
    ok3   = add_bundle(selfdir + "Ok3Handler.java", :name => "Ok3Handler")
    compile_bundles(@vespa.nodeproxies.values.first)

    clear_bundles
    start(selfdir + "app", :bundles => [ok1])
    verify_non_configurable_handler_response("Ok1")

    puts ">>>>>>>>>>>> Deploying the 2. app, with a handler that throws an exception during construction"
    clear_bundles
    reconfig_failures = num_container_failures
    deploy_without_waiting(selfdir + "app2", :bundles => [fail2])
    wait_for_next_application_failure(reconfig_failures)
    verify_non_configurable_handler_response("Ok1")

    puts ">>>>>>>>>>>> Deploying the 3. app, with a valid handler"
    clear_bundles
    deploy(selfdir + "app3", :bundles => [ok3])
    verify_non_configurable_handler_response("Ok3")

    verify_num_app_failures(reconfig_failures + 1)
  end

  def test_component_reconfig_works_after_failed_reconfig
    set_expected_logged(/Error constructing 'com.yahoo.test.ConfigurableExceptionHandler'/)

    bundle = add_bundle_dir(File.expand_path(selfdir), "com.yahoo.test.ConfigurableExceptionHandler")
    compile_bundles(@vespa.nodeproxies.values.first)

    clear_bundles
    start(configurable_handler_app(false, 1), :bundles => [bundle])
    verify_configurable_handler_response("Ok1")

    reconfig_failures = num_container_failures
    deploy_app(configurable_handler_app(true, 2), :bundles => [bundle])
    wait_for_next_application_failure(reconfig_failures)
    verify_configurable_handler_response("Ok1")

    deploy(configurable_handler_app(false, 3), :bundles => [bundle])
    verify_configurable_handler_response("Ok3")

    verify_num_app_failures(reconfig_failures + 1)
  end

  def configurable_handler_app(do_throw, generation)
    ContainerApp.new.
           container(Container.new.
                     handler(Handler.new("com.yahoo.test.ConfigurableExceptionHandler").
                                 binding("http://*/ConfigurableException").
                                 config(ConfigOverride.new(:"com.yahoo.vespatest.exception").
                                            add("generation", generation.to_s).
                                            add("doThrow", do_throw.to_s))))
  end

  def verify_configurable_handler_response(expected)
    result = @container.search("/ConfigurableException")
    assert_equal(expected, result.xmldata)
  end

  def verify_non_configurable_handler_response(expected)
    result = @container.search("/#{expected}")
    assert_match(/#{expected}/, result.xmldata, "Did not get expected response.")
  end

  def verify_num_app_failures(expected)
    assert_equal(expected, @app_failures, "Expected #{expected} app failures, got #{@app_failures}")
  end

  # Candidate for moving to testcase.rb
  def wait_for_next_application_failure(failures_until_now)
    failures_now = 0
    count = 0
    while count < 90
      begin
        count += 1
        failures_now = num_container_failures
        if failures_now < failures_until_now+1
          puts "* Try #{count}, waiting for application failure no. #{failures_until_now+1}, got #{failures_now}"
          sleep 1
        else
          puts "Got application failure no. #{failures_now}"
          @app_failures = failures_now
          break
        end
      end
    end
    if failures_now != failures_until_now+1
      flunk "Did not get application failure in #{count} seconds"
    end
  end

  def num_container_failures
    regex = Regexp.new('.*container.+Reconfiguration failed')
    log = ''
    num_failures = 0
    vespa.logserver.get_vespalog { |data|
      log << data
      nil
    }
    log.each_line do |line|
      num_failures += 1 if regex.match(line)
    end
    num_failures
  end

  def teardown
    stop
  end

end
