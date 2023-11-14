# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'container_test'
require 'app_generator/container_app'

class RestartOnDeploy < ContainerTest

  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

  def setup
    set_owner('gv')
    set_description("Verify that the 'restartOnDeploy' setting disables reconfiguration.")
  end

  def enable_debug_logging
    @container.logctl('container:com.yahoo.container.di', 'debug=on')
    @container.logctl('container:com.yahoo.container.jdisc', 'debug=on')
  end

  def test_restart_on_deploy
    add_bundle(selfdir + "HelloWorld.java")
    app = create_application('http://*/test')
    start(app)
    verify_response('/test', 'Hello, world!')

    enable_debug_logging
    app = create_application('http://*/should_not_work')
    output = container_deploy(app, {})
    verify_no_reconfig(@container, output)
    verify_response('/test', 'Hello, world!')
    assert_response_code('/should_not_work', 404)
  end

  def create_application(binding)
    config = ConfigOverride.new(:'container.qr').
        add('restartOnDeploy', 'true')

    ContainerApp.new.container(
        Container.new.
            handler(Handler.new('com.yahoo.vespatest.HelloWorld').
                        binding(binding)).
            config(config))
  end

  def verify_response(path, expected)
    result = @container.search(path)
    assert_match(/#{expected}/, result.xmldata, 'Did not get expected response.')
  end

  def assert_response_code(path, expected)
    response = @container.http_get('localhost', 0, path)
    assert_equal(expected, response.code.to_i, "HTTP Response code #{response.code} doesn't match expected value (#{expected}) Response returned: #{response}")
  end

  def verify_no_reconfig(qrserver, deploy_output)
    checksum = get_checksum(deploy_output)
    puts "New application checksum: #{checksum}"
    limit = 20
    start = Time.now.to_i
    puts "start=#{start}"
    while Time.now.to_i - start < limit
      begin
        sleep 1
        res = qrserver.search("/ApplicationStatus")
        root = JSON.parse(res.xmldata)
        qrs_checksum = root['application']['meta']['checksum']

        if qrs_checksum != checksum
          puts "Still getting previous application checksum #{qrs_checksum}"
        else
          flunk "Got new application checksum #{checksum}, but reconfig is disabled."
        end
      rescue RuntimeError => e
        puts "Failed getting application status: #{e}"
      end
    end
  end

  def teardown
    stop
  end

end
