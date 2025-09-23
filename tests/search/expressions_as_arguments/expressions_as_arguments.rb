# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class ExpressionsAsArguments < IndexedStreamingSearchTest

  def setup
    @valgrid = false
    set_owner("lesters")
    set_description("Validate expressions as arguments to functions")
  end


  def test_expressions_as_args
    deploy_app(SearchApp.new.sd(selfdir + 'app/schemas/test.sd'))
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

