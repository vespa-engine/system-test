# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

# Regression test for vespa-engine/vespa#36843.
#
# vespa-proton-bin crashed with SIGSEGV in NumericFunctionNode::VectorHandler
# when a grouping expression invoked a binary numeric op (e.g. add/mul) and
# one operand vector was empty. The handler resized result to the larger
# argSize, then filled values using modulo indexing.
#
# If oldSize == 0 or argSize == 0 the modulo caused integer division by zero.
# The fix in NumericFunctionNode::handle skips the loop when either size is 0.
#
# Goal of this test: prove proton does not crash for any (a empty? b empty?)
# combination when grouping by add(a,b) or mul(a,b). The assertions on group
# keys do NOT validate documented semantics — they pin the current emergent
# behaviour of the handler (e.g. mul with the left operand empty collapses to
# zeros). If the handler is rewritten to preserve the non-empty operand
# symmetrically, update the expectations accordingly.
class GroupingFunctionNodeEmptyArgBug < IndexedStreamingSearchTest

  def setup
    set_owner('johsol')
    set_description('Test that proton does not crash when a grouping ' +
                    'add/mul has an empty array operand (vespa#36843). ')
  end

  def test_add_mul_empty_array_operand
    deploy_app(SearchApp.new.sd(selfdir + 'test.sd'))
    start
    feed_and_wait_for_docs('test', 4, :file => selfdir + 'docs.json')

    # add(a, b): with one operand empty the non-empty operand is preserved.
    assert_group_keys('n:1', 'add(a,b)', [5, 7, 9])
    assert_group_keys('n:2', 'add(a,b)', [1, 2, 3])
    assert_group_keys('n:3', 'add(a,b)', [4, 5, 6])
    assert_group_keys('n:4', 'add(a,b)', [])

    # mul(a, b): right operand empty preserves left (n:2). Left operand empty
    # (n:3) resizes result to argSize zero-initialised elements; the combine
    # loop then multiplies the zeros by b, leaving [0, 0, 0] which collapses
    # to a single group with key 0. Both operands empty leaves result empty.
    assert_group_keys('n:1', 'mul(a,b)', [4, 10, 18])
    assert_group_keys('n:2', 'mul(a,b)', [1, 2, 3])
    assert_group_keys('n:3', 'mul(a,b)', [0])
    assert_group_keys('n:4', 'mul(a,b)', [])
  end

  def assert_group_keys(query, expr, expected)
    url = "/?query=#{query}&hits=0&select=all(group(#{expr})each(output(count())))"
    json = search(url).json
    groups = json.dig('root', 'children', 0, 'children', 0, 'children') || []
    actual = groups.map { |g| g['value'].to_i }.sort
    assert_equal(expected.sort, actual, "expr=#{expr} query=#{query}")
  end
end
