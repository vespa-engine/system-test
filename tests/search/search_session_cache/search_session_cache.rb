# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SearchSessionCache < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test using search session cache")
  end

  def test_search_session_cache
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "data.xml")

    result = search_base("query=title:foo&tracelevel=3&ranking.profile=test1&ranking.queryCache=false&timeout=9.9")
    assert(result.xmldata.match("Resending query during document summary fetching"), "Resending query data when the feature cache is turned off")
    assert_equal('{"fieldMatch(title)":1.0,"vespa.summaryFeatures.cached":0.0}', result.hit[0].comparable_fields["summaryfeatures"])

    result = search_base("query=title:foo&tracelevel=3&ranking.profile=test1&ranking.queryCache=true&timeout=9.9")
    # Sent summary requests by RPC as the query cache is on
    assert(result.xmldata.match("Sending 1 summary fetch RPC requests"), "Sending 1 summary fetch RPC requests")
    assert_equal('{"fieldMatch(title)":1.0,"vespa.summaryFeatures.cached":0.0}', result.hit[0].comparable_fields["summaryfeatures"])
  end

  def teardown
    stop
  end

end
