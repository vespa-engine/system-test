# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'testcase'

class ContainerTest < TestCase
  alias_method :super_deploy, :deploy
  alias_method :super_start, :start

  # Returns the modulename for this testcase superclass.
  # It is used by factory for categorizing tests.
  def modulename
    "container"
  end

  def can_share_configservers?(method_name=nil)
    true
  end

  # Only for redeployment.
  # The first app must be deployed with 'start'
  def deploy(app, params={})
    output = container_deploy(app, params)
    @container = (vespa.container.values.first || vespa.qrserver.values.first)
    wait_for_application(@container, output)
    output
  end

  # First deployment
  # 'stop' must always be called between calls to this method
  def start(app, params={})
    container_deploy(app, params)
    # First look for container, then for qrserver (app that includes <search>)
    @container = (vespa.container.values.first || vespa.qrserver.values.first)
    super_start
  end

  # Used to deploy an application that is expected to fail
  # The first app must still be deployed with 'start'
  def deploy_without_waiting(app, params={})
    container_deploy(app, params)
  end

  # Internal helper method
  def container_deploy(app, params)
    app_location = get_app_location(app)
    @node = vespa.nodeproxies.values.first
    super_deploy(app_location, nil, params)
  end

  # Internal helper method to return the location of a possibly generated application
  def get_app_location(folder_or_generated)
    if folder_or_generated.is_a? String
      folder = folder_or_generated
    else
      generated = folder_or_generated
      folder = vespa.create_services_xml(generated.services_xml)
    end
    folder
  end

  def param_setup(params)
    @params = params
    setup
  end

  def self.testparameters
    { "CLUSTER" => { :deploy_mode => "CLUSTER" } }
  end

end
