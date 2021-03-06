# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'

class HugeRankProperties < SearchTest

  def setup
    set_owner("havardpe")
  end

  # Test that the config system works for large rank expressions
  def test_huge_rankproperties
    @valgrind = false
    deploy_app(SearchApp.new.sd(selfdir + "huge_expression.sd").
                          rank_expression_file(selfdir + "huge.expression"))
    start(360)
    feed_and_wait_for_docs("huge_expression", 1, :file => selfdir + "doc2.xml")
    # The huge expression should give 25000*1 relevancy
    assert_relevancy("test&ranking=rank1", 25000, 0)
  end
  
  def teardown
    stop
  end

end
