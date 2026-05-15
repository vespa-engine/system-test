# Copyright Vespa.ai. All rights reserved.
require 'test_base'

class UnitTest
  include TestBase
  include Test::Unit::Assertions
  include BacktraceFilter

  def initialize(vespamodel)
    deploy_mock(vespamodel)
  end

end
