# Copyright Vespa.ai. All rights reserved.

require 'json'
require 'tensor_result'

module VespaAssertions

  def assert_json_string_equal(expected, actual)
    assert_equal(JSON.parse(expected), JSON.parse(actual))
  end

  def assert_tensors_equal(expected, actual)
    exp = TensorResult.new(expected)
    act = TensorResult.new(actual)
    assert_equal(exp, act, "Tensors should be equal: Expected #{exp} != Actual #{act}")
  end

end
