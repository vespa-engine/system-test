# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'app_generator/container_app'
require 'app_generator/servlet'
require 'container_test'
require 'net/http'

class ServletReconfig < ContainerTest
  include AppGenerator

  SERVLET_ID = "my-servlet"
  SERVLET_CLASS = "com.yahoo.test.servlet.ServletWithCloudConfigAndServletConfig"
  SERVLET_BUNDLE = "reconfig_servlet"

  @resource

  def setup
    set_owner("gjoranv")
    set_description("Verify that custom servlets can be reconfigured.")

    @resource = add_bundle_dir(selfdir + "servlet", "reconfig_servlet", :name => 'resource')
    compile_bundles(@vespa.nodeproxies.values.first)
  end


  def test_cloud_config_reconfig
    path = 'my-path'
    message1 = 'Hello!'
    message2 = 'Hello again!'

    deoploy_and_start(application_with_cloud_config(path, message1))
    verify_cloud_config_response(path, message1)

    deploy_and_wait_for_reconfig(application_with_cloud_config(path, message2))
    verify_cloud_config_response(path, message2)
  end

  def test_servlet_config_reconfig
    path = 'my-path'
    message1 = 'Hello!'
    message2 = 'Hello again!'

    deoploy_and_start(application_with_servlet_config(path, message1))
    verify_servlet_config_response(path, message1)

    deploy_and_wait_for_reconfig(application_with_servlet_config(path, message2))
    verify_servlet_config_response(path, message2)
  end

  def test_path_reconfig
    path1 = 'my-path'
    path2 = 'my-path2'

    deoploy_and_start(create_application_without_config(path1))
    verify_empty_response(path1)

    deploy_and_wait_for_reconfig(create_application_without_config(path2))
    verify_empty_response(path2)
  end

  def deoploy_and_start(application)
    start(application, :bundles => [@resource])
  end

  def deploy_and_wait_for_reconfig(application)
    deploy(application, :bundles => [@resource])
    wait_for_reconfig
  end


  def application_with_cloud_config(path, cloudConfigMessage)
    create_application(path, cloudConfigMessage, nil)
  end

  def application_with_servlet_config(path, servletConfigMessage)
    create_application(path, nil, servletConfigMessage)
  end

  def create_application_without_config(path)
    create_application(path, nil, nil)
  end

  def create_application(path, cloudConfigMessage, servletConfigMessage)
    servlet = Servlet.new(SERVLET_ID).
                        klass(SERVLET_CLASS).
                        bundle(SERVLET_BUNDLE).
                        path(path)

    if cloudConfigMessage != nil
      cloudConfig = ConfigOverride.new('com.yahoo.test.message').add('message', cloudConfigMessage)

      servlet.config(cloudConfig)
    end

    if servletConfigMessage != nil
      servletConfig = ServletConfig.new().add("message", servletConfigMessage)

      servlet.servlet_config(servletConfig)
    end

    ContainerApp.new.container(Container.new.servlet(servlet))
  end

  def verify_empty_response(path)
    verify_response(path, '', '')
  end

  def verify_cloud_config_response(path, expectedCloudConfigValue)
    verify_response(path, expectedCloudConfigValue, '')
  end

  def verify_servlet_config_response(path, expectedServletConfigValue)
    verify_response(path, '', expectedServletConfigValue)
  end

  def verify_response(path, expectedCloudConfigValue, expectedServletConfigValue)
    result = @container.http_get2('/' + path)
    data = JSON.parse(result.body)

    assert(data.has_key? "cloudConfigValue")
    assert(data.has_key? "servletConfigValue")

    assert_equal(expectedCloudConfigValue, data["cloudConfigValue"], "Did not get the proper servletConfig response.")
    assert_equal(expectedServletConfigValue, data["servletConfigValue"], "Did not get the proper cloudConfig response.")
  end

  def teardown
    stop
  end

end
