# Copyright Vespa.ai. All rights reserved.
require 'test/unit/assertions'

module Assertions
  include Test::Unit::Assertions

  # Passes if the JSON parsed value of expected string is
  # equal to the JSON parsed value of actual.
  def assert_json_string_equal(expected, actual)
      assert_equal(JSON.parse(expected), JSON.parse(actual))
  end

  # Converts parsed canonical tensors to objects and compares
  def assert_tensors_equal(expected, actual)
      exp = TensorResult.new(expected)
      act = TensorResult.new(actual)
      assert_equal(exp, act, "Tensors should be equal: Expected #{exp} != Actual #{act}")
  end

end
