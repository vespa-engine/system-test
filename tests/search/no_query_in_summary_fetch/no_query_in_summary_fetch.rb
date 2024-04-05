# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class NoQueryInSummaryFetch < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that we are not resending the query during summary fetching unnecessarily")
  end

  def test_no_query_in_summary_fetch
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "data.json")

    save_result("query=title:foo&tracelevel=3&ranking.profile=test1&ranking.queryCache=false&timeout=9.9", "foo.xml")

    # Need as cache is off and required by rank profile test1
    result = search_base("query=title:foo&tracelevel=3&ranking.profile=test1&ranking.queryCache=false&timeout=9.9")
    puts "hit 0: #{result.hit[0]}"
    puts "hit 0 sf: #{result.hit[0].field['summaryfeatures']}"
    assert(result.xmldata.match("Resending query during document summary fetching"), "Resending query data when the feature cache is turned off")
    assert_features({'fieldMatch(title)' => 1.0}, result.hit[0].field['summaryfeatures'])

    # Not needed as explicit cached
    result = search_base("query=title:foo&tracelevel=3&ranking.profile=test1&ranking.queryCache=true&timeout=9.9")
    assert(result.xmldata.match("Not resending query during document summary fetching"), "Not resending query data when the feature cache is turned off")
    assert_features({'fieldMatch(title)' => 1.0}, result.hit[0].field['summaryfeatures'])

    # Not needed by query
    result = search_base("query=title:foo&tracelevel=3&timeout=9.9")
    assert(result.xmldata.match("Not resending query during document summary fetching"), "Not resending query data when not required by query for summary construction")
   end

  def teardown
    stop
  end

end
