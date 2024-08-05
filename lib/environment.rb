# Copyright Vespa.ai. All rights reserved.

require 'environment_base'

# A singleton providing the default environment in which to run tests.
# To access, use "Environment.instance" before fields and methods.
#
# If the environment needs to be customized when running tests,
# this can be replaced by an environment-specific implementation.
class Environment < EnvironmentBase

  def self.instance
    @@instance
  end

  def initialize
    super("/opt/vespa", "vespa", 8080)
  end

  @@instance = Environment.new

  private_class_method :new
end
