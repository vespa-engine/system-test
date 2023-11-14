# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require '../filter'

class FilterTest < Test::Unit::TestCase
  include Perf

  def setup
    @input = [0, 2, 4, 6, 4, 2, 0]
  end

  def test_sma_0
    assert_raise ArgumentError do
      Filter.sma(@input, 0)
    end
  end

  def test_sma_1
    actual = Filter.sma(@input, 1)
    assert_equal(@input, actual)
  end

  def test_sma_2
    expected = [0, 1, 3, 5, 5, 3, 1]
    actual = Filter.sma(@input, 2)
    assert_equal(expected, actual)
  end

  def test_sma_3
    expected = [0.0, 1.0, 2.0, 4.0, 4.66666666666667, 4.0, 2.0]
    actual = Filter.sma(@input, 3)
    for i in 0..@input.size-1
      assert_in_delta(expected[i], actual[i], 0.001)
    end
  end

  def test_sma_too_long
    assert_raise ArgumentError do
      Filter.sma(@input, @input.size)
    end
  end

end