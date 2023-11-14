# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'assertions'

class UnitTest
  include TestBase
  include Assertions

  def initialize(vespamodel)
    deploy_mock(vespamodel)
  end

end
