# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Grouping < IndexedSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("bjorncs")
    deploy_app(SearchApp.new.sd("#{selfdir}/purchase.sd").sd("#{selfdir}/simple.sd").num_parts(2))
    start
  end

  def test_grouping
    feed_and_wait_for_docs("purchase", 20, :file => "#{selfdir}/docs.xml", :maxpending => 1)

    # Basic Grouping
    assert_grouping("purchase", "all(group(customer) each(output(sum(price))))",
                    "#{selfdir}/example1.json")

    assert_grouping("purchase", "all(group(time.date(date)) each(output(sum(price))))",
                    "#{selfdir}/example2.json")

    # Expressions
    assert_grouping("purchase", "all(group(mod(div(date,mul(60,60)),24)) each(output(sum(price))))",
                    "#{selfdir}/example3.json")

    assert_grouping("purchase", "all(group(customer) each(output(sum(mul(price,sub(1,tax))))))",
                    "#{selfdir}/example4.json")

    # Ordering and Limiting Groups
    assert_grouping("purchase", "all(group(customer) max(2) precision(3) order(-count()) each(output(count(), sum(price))))",
                    "#{selfdir}/example5.json")

    # Presenting Hits per Group
    assert_grouping("purchase", "all(group(customer) each(max(3) each(output(summary()))))",
                    "#{selfdir}/example6.json")

    # Nested Groups
    assert_grouping("purchase", "all(group(customer) each(group(time.date(date)) each(output(sum(price)))))",
                    "#{selfdir}/example7.json")

    assert_grouping("purchase", "all(group(customer) each(max(1) output(sum(price)) each(output(summary()))) as(sumtotal)" +
                    "                    each(group(time.date(date)) each(max(10) output(sum(price)) each(output(summary())))))",
                    "#{selfdir}/example8.json")
  end

  def test_grouping_summary
    feed_and_wait_for_docs("simple", 1, :file => "#{selfdir}/simple-feed.xml", :maxpending => 1)
    assert_grouping("simple", "all(group(str_attr)max(1)each(max(1)each(output(summary()))))",
                    "#{selfdir}/simple-result.json")
  end

  def assert_grouping(doc_type, grouping, file)
    my_assert_query("/search/?hits=0&query=sddocname:#{doc_type}&select=#{grouping}", file)
    my_assert_query("/search/?hits=0&yql=select%20%2A%20from%20search%20where%20sddocname%20contains%20%22#{doc_type}%22%20%7C#{grouping}%3B", file)
  end

  def my_assert_query(query, file)
    act = search_with_timeout(5.0, query)
    exp = create_resultset(file)
    assert_equal(exp.hitcount, act.hitcount)
    actjson = act.json
    expjson = exp.json
    assert_equal(actjson['root']['coverage'], expjson['root']['coverage'])
    assert_equal(expjson['root']['children'], actjson['root']['children'])
  end

  def teardown
    stop
  end

end
