# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class PartialUpdateIllegalOperations < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  def test_divide_by_zero
    set_description("Test that divide by zero operations are stopped during feeding")
    deploy_app(SearchApp.new.sd(selfdir + "dbzero.sd"))
    start

    feed_and_wait_for_docs("dbzero", 1, :file => selfdir + "dbzero-feed.xml")

    query = "query=sddocname:dbzero"
    srf = selfdir + "dbzero-result.json"
    ftc = ["sint", "sfloat", "wsint", "wsfloat", "wsstr"]

    wait_for_hitcount(query, 1)
    assert_result(query, srf, nil, ftc)

    output = feedfile(selfdir + "dbzero-update.xml", :exceptiononfailure => false)

    assert_output(output, "Division by zero.")

    assert_result(query, srf, nil, ftc)
  end

  def assert_output(output, expected)
    assert(output.include?(expected), "Expected '#{expected}' in feeder output: #{output}")
  end

  def teardown
    stop
  end

end
