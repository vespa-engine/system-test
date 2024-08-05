# Copyright Vespa.ai. All rights reserved.
require 'container_test'
require 'app_generator/container_app'

class ComponentInvalidApp2 < ContainerTest

  # No point in running standalone, as it does not support reconfig
  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

  def timeout_seconds
    return 900
  end

  def setup
    set_owner("gjoranv")
    set_description("Verifies that the container stops subscribing for config from app 1 after app 2 fails and app 3 has been successfully deployed.")
    @app_failures = 0
  end

=begin
  Three config generations:

  gen 1: ok - component with a custom config with a param without default value
  gen 2: fail - remove above component, and add component (no config) that throws
  gen 3: ok - only one component (that does not take the custom config)

  Until a bugfix was applied, the container would be stuck in a bad state where it tried to instantiate the custom config for gen 3.

=end
  def mute_test_app_with_config_then_throw_then_ok_without_config
    set_expected_logged(/Error constructing 'com.yahoo.test.Fail2Handler'/)

    ok1 = add_bundle_dir(File.expand_path(selfdir), "com.yahoo.test.Ok1Handler")
    fail2 = add_bundle(selfdir + "Fail2Handler.java", :name => "Fail2Handler")
    ok3   = add_bundle(selfdir + "Ok3Handler.java", :name => "Ok3Handler")
    compile_bundles(@vespa.nodeproxies.values.first)

    clear_bundles
    start(ok1_app, :bundles => [ok1])
    verify_response("Ok1")

    puts ">>>>>>>>>>>> Deploying the 2. app, with a handler that throws an exception during construction"
    clear_bundles
    reconfig_failures = num_container_failures
    deploy_without_waiting(fail2_app, :bundles => [fail2])
    wait_for_next_application_failure(reconfig_failures)
    verify_response("Ok1")

    puts ">>>>>>>>>>>> Deploying the 3. app, with a valid handler"
    clear_bundles
    deploy(ok3_app, :bundles => [ok3])
    verify_response("Ok3")

    verify_num_app_failures(reconfig_failures + 1)
  end

  def ok1_app()
    config = ConfigOverride.new(:"com.yahoo.test.response").
      add("response", "Ok1")

    ContainerApp.new.container(
      Container.new.
        handler(Handler.new("com.yahoo.test.Ok1Handler").
          binding("http://*/Ok1").
          config(config)))
  end

  def fail2_app()
    cfg = ConfigOverride.new(:"com.yahoo.test.response").
      add("response", "Ok1")

    ContainerApp.new
                .container(Container.new.
                  handler(Handler.new("com.yahoo.test.Fail2Handler")).
                  config(cfg))
  end

  def ok3_app()
    ContainerApp.new.container(
      Container.new.
        handler(Handler.new("com.yahoo.test.Ok3Handler").
          binding("http://*/Ok3")))
  end


  def verify_response(expected)
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
    if failures_now < failures_until_now+1
      flunk "Did not get application failure in #{count} seconds"
    elsif failures_now > failures_until_now+1
           puts "Got #{failures_now} application failures, expected only #{failures_until_now+1}"
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
