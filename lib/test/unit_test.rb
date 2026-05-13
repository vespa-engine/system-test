# Copyright Vespa.ai. All rights reserved.
require 'assertions'
require 'test_base'

class UnitTest
  include TestBase
  include Test::Unit::Assertions

  def initialize(vespamodel)
    deploy_mock(vespamodel)
  end

end
