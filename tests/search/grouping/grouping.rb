# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Grouping < IndexedSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("bjorncs")
    deploy_app(SearchApp.new.sd("#{selfdir}/purchase.sd"))
    start
  end

  def test_grouping
    feed_and_wait_for_docs("purchase", 20, :file => "#{selfdir}/docs.xml", :maxpending => 1);

    # Basic Grouping
    assert_grouping("all(group(customer) each(output(sum(price))))",
                    "#{selfdir}/example1.xml")

    assert_grouping("all(group(time.date(date)) each(output(sum(price))))",
                    "#{selfdir}/example2.xml")

    # Expressions
    assert_grouping("all(group(mod(div(date,mul(60,60)),24)) each(output(sum(price))))",
                    "#{selfdir}/example3.xml")

    assert_grouping("all(group(customer) each(output(sum(mul(price,sub(1,tax))))))",
                    "#{selfdir}/example4.xml")

    # Ordering and Limiting Groups
    assert_grouping("all(group(customer) max(2) precision(3) order(-count()) each(output(count(), sum(price))))",
                    "#{selfdir}/example5.xml")

    # Presenting Hits per Group
    assert_grouping("all(group(customer) each(max(3) each(output(summary()))))",
                    "#{selfdir}/example6.xml")

    # Nested Groups
    assert_grouping("all(group(customer) each(group(time.date(date)) each(output(sum(price)))))",
                    "#{selfdir}/example7.xml")

    assert_grouping("all(group(customer) each(max(1) output(sum(price)) each(output(summary()))) as(sumtotal)" +
                    "                    each(group(time.date(date)) each(max(10) output(sum(price)) each(output(summary())))))",
                    "#{selfdir}/example8.xml")
  end

  def assert_grouping(grouping, file)
    my_assert_query("/search/?hits=0&query=sddocname:purchase&select=#{grouping}", file)
    my_assert_query("/search/?hits=0&yql=select%20%2A%20from%20sources%20%2A%20where%20sddocname%20contains%20%27purchase%27%20%7C%20#{grouping}%3B", file)
  end

  def my_assert_query(query, file)
    puts(query)
    if (SAVE_RESULT && !check_xml_result(query, file)) then
      File.open(file, "w") { |f| f.write(search(query).xmldata) }
    end
    assert_xml_result_with_timeout(5.0, query, file)
  end

  def teardown
    stop
  end

end
