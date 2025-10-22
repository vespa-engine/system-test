# Copyright Vespa.ai. All rights reserved.

require 'tempfile'

require 'performance/system'
require 'performance/resultmodel'
require 'test/unit'

class MockModel
  def initialize(value)
    @value = value
  end
  def has_parameter?(param)
    true
  end

  def metric(name, source)
    @value
  end

  def parameter(name)
    @value
  end
end

class ResultModelTest < Test::Unit::TestCase

  def test_custom_producer_parsing
    # Float
    m1 = MockModel.new("1.5")
    assert_equal(1.5, Perf.customproducer('a').call(m1))
    # Integer
    m2 = MockModel.new("5")
    assert_equal(5, Perf.customproducer('a').call(m2))
    # Float
    m3 = MockModel.new("howdy")
    assert_equal("howdy", Perf.customproducer('a').call(m3))
  end

end
