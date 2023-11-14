# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ExpressionsAsArguments < IndexedSearchTest

  def setup
    @valgrid = false
    set_owner("lesters")
    set_description("Validate expressions as arguments to functions")
  end

  def teardown
    stop
  end

  def test_expressions_as_args
    deploy(selfdir + "app/")
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "feed.json")
    result = search("query=sddocname:test&ranking=test")
    summary = result.hit[0].field['summaryfeatures']

    puts summary

    assert_feature(summary, "test_constant", 13.8596)
    assert_feature(summary, "test_arithmetic", 4)
    assert_feature(summary, "test_not_neg", 1)
    assert_feature(summary, "test_if_in", 1)
    assert_feature(summary, "test_function", 0.291926)
    assert_feature(summary, "test_embraced", 4)
    assert_feature(summary, "test_func", 1.3)
    assert_feature(summary, "test_tensor_func_with_expr", 1.5)
    assert_feature(summary, "test_func_with_tensor_func", 1.05)
    assert_feature(summary, "test_func_with_slice", 0.01)
    assert_feature(summary, "test_func_via_func_with_expr", 1.5)
  end

  def assert_feature(summary, name, value)
    assert_approx(summary[name], value)
  end

end

