# Copyright Vespa.ai. All rights reserved.
require 'assertions'
require 'test_base'

class UnitTest
  include TestBase
  include Assertions

  def initialize(vespamodel)
    deploy_mock(vespamodel)
  end

end
