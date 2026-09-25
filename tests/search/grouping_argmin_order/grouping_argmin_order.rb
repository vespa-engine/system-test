# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class GroupingArgminOrder < IndexedStreamingSearchTest

  def setup
    set_owner("johsol")
    set_description("Use case: order groups by the value argmin/argmax selects, e.g. the title of the cheapest " +
                    "track per artist. Covers ascending and descending order on numeric and string values, a group " +
                    "where no hit has the key, a hit without the key that must be skipped, and max() with precision.")
  end

  def test_order_by_argmin_argmax
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").num_parts(2))
    start
    feed_and_wait_for_docs("test", 9, :file => selfdir + "docs.json")

    # docs.json is made so that the value order differs from the group id order and the count order:
    #   argmin(n, d): a1=5.0 a2=2.0 a3=4.0 a4=0.0 a5=-2.0     argmin(n, s): a1="e" a2="b" a3="d" a4="" a5="0"
    #   argmax(n, d): a1=1.0 a2=6.0 a3=3.0 a4=0.0 a5=-2.0     argmax(n, s): a1="a" a2="f" a3="c" a4="" a5="0"
    # No hit in a4 has the key n, so it has no value: the output is null, and it sorts as the type default
    # (0.0 or "") does.
    # a5 has one hit without the key, which must be skipped.
    check_query('all(group(a) order(argmin(n, d)) each(output(argmin(n, d))))', 'argmin-asc')
    check_query('all(group(a) order(-argmin(n, d)) each(output(argmin(n, d))))', 'argmin-desc')
    check_query('all(group(a) order(argmax(n, d)) each(output(argmax(n, d))))', 'argmax-asc')
    check_query('all(group(a) order(-argmax(n, d)) each(output(argmax(n, d))))', 'argmax-desc')
    check_query('all(group(a) order(argmin(n, s)) each(output(argmin(n, s))))', 'argmin-string-asc')
    check_query('all(group(a) order(-argmax(n, s)) each(output(argmax(n, s))))', 'argmax-string-desc')

    # max() with a precision covering every group, so the result does not depend on how documents are
    # distributed over the two content nodes. A tighter precision may prune a group on one node before merging.
    check_query('all(group(a) max(2) precision(10) order(-argmin(n, d)) each(output(argmin(n, d))))', 'argmin-desc-max2')
    check_query('all(group(a) max(2) precision(10) order(argmax(n, d)) each(output(argmax(n, d))))', 'argmax-asc-max2')

    # A group where no hit has the key renders null for every value type, also when nothing is ordered by it.
    check_query('all(group(a) each(output(argmin(n, d), argmin(n, s), argmax(n, d))))', 'no-value-null')
  end

  def check_query(select, file)
    query = "/?query=sddocname:test&select=#{select}&hits=0&timeout=10"
    puts "check #{query} with #{file}"
    assert_result(query, selfdir + "answers/#{file}.json")
  end

end
