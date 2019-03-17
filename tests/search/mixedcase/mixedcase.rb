# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class MixedCase < IndexedSearchTest

  def setup
    set_owner("geirst")
    set_description("Check index names are case insensitive in queries by doing queries only differing in case")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_mixedcase
    feed_and_wait_for_docs("music", 3, :file => selfdir+"mixedcase.2.xml")

    puts "Details: Checking no docs are available for the search term without index."
    assert_result_matches("query=2000",selfdir+"nohits.result","total-hit-count")

    puts "Details: Checking doc is found with correct casing"
    assert_result_matches("query=YeaR:2000",selfdir+"onehit.result","total-hit-count")

    puts "Details: Checking doc is found with all lower case in query"
    assert_result_matches("query=year:2000",selfdir+"onehit.result","total-hit-count")

    puts "Details: Checking doc is found mixed, incorrect case in query"
    assert_result_matches("query=Year:2000",selfdir+"onehit.result","total-hit-count")

    puts "Details: Checking doc is found with all upper case in query"
    assert_result_matches("query=YEAR:2000",selfdir+"onehit.result","total-hit-count")

    puts "Details: Checking doc is found with all upper case in query, attribute search"
    assert_result_matches("query=ANNO:2000",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking doc is found with all lower case in query, attribute search"
    assert_result_matches("query=anno:2000",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking doc is found with correct case in query, attribute search"
    assert_result_matches("query=AnnO:2000",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking no hits, attribute search"
    assert_result_matches("query=AnnO:2001",selfdir+"nohits.result","total-hit-count")

    puts "Details: Checking doc is found with all upper case in query, attribute search, nonalphanumeric char in query"
    assert_result_matches("query=ANNO:1985-12",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking doc is found with all lower case in query, attribute search, nonalphanumeric char in query"
    assert_result_matches("query=anno:1985-12",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking doc is found with correct case in query, attribute search, nonalphanumeric char in query"
    assert_result_matches("query=AnnO:1985-12",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking no hits, attribute search, nonalphanumeric char in query"
    assert_result_matches("query=AnnO:1985+12",selfdir+"nohits.result","total-hit-count")

    puts "Details: Checking doc is found with all upper case in query, attribute search, weighted set"
    assert_result_matches("query=YEARSET:2000",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking doc is found with all lower case in query, attribute search, weighted set"
    assert_result_matches("query=yearset:2000",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking doc is found with correct case in query, attribute search, weighted set"
    assert_result_matches("query=YearSet:2000",selfdir+"onehit.result","total-hit-count")
    puts "Details: Checking no hits, attribute search, weighted set"
    assert_result_matches("query=YearSet:2001",selfdir+"nohits.result","total-hit-count")

    puts "Details: Checking doc is found with all lower case in query, attribute search, weighted set, nonalphanumeric char in query"
    assert_result_matches("query=yearset:threethousand////one/lolz]]",selfdir+"onehit.result","total-hit-count")

  end

  def teardown
    stop
  end

end
