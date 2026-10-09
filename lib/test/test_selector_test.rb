# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require 'test_selector'

class TestSelectorTest < Test::Unit::TestCase
  class FooTest; end
  class BarTest; end

  def setup
    @foo_a = FooTest.new
    @foo_b = FooTest.new
    @bar = BarTest.new
    @test_objects = { @foo_a => :test_a, @foo_b => :test_b__STREAMING, @bar => :test_a }
  end

  def test_selects_all_without_names
    assert_equal([@test_objects, []], TestSelector.select(@test_objects, nil))
  end

  def test_selects_all_with_empty_names
    assert_equal([@test_objects, []], TestSelector.select(@test_objects, []))
  end

  def test_selects_named_tests_only
    selected, unknown = TestSelector.select(@test_objects, ["TestSelectorTest::FooTest::test_b__STREAMING",
                                                            "TestSelectorTest::BarTest::test_a"])
    assert_equal({ @foo_b => :test_b__STREAMING, @bar => :test_a }, selected)
    assert_equal([], unknown)
  end

  def test_reports_names_not_found
    selected, unknown = TestSelector.select(@test_objects, ["TestSelectorTest::FooTest::test_a",
                                                            "TestSelectorTest::FooTest::test_removed",
                                                            "Removed::test_a"])
    assert_equal({ @foo_a => :test_a }, selected)
    assert_equal(["Removed::test_a", "TestSelectorTest::FooTest::test_removed"], unknown)
  end

end
