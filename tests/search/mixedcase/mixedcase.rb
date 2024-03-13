# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class MixedCase < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    set_description("Check index names are case insensitive in queries by doing queries only differing in case")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def test_mixedcase
    feed_and_wait_for_docs("music", 3, :file => selfdir+"mixedcase.2.json")

    puts "Details: Checking no docs are available for the search term without index."
    assert_hitcount("query=2000", 0)

    puts "Details: Checking doc is found with correct casing"
    assert_hitcount("query=YeaR:2000", 1)

    puts "Details: Checking doc is found with all lower case in query"
    assert_hitcount("query=year:2000", 1)

    puts "Details: Checking doc is found mixed, incorrect case in query"
    assert_hitcount("query=Year:2000", 1)

    puts "Details: Checking doc is found with all upper case in query"
    assert_hitcount("query=YEAR:2000", 1)

    puts "Details: Checking doc is found with all upper case in query, attribute search"
    assert_hitcount("query=ANNO:2000", 1)
    puts "Details: Checking doc is found with all lower case in query, attribute search"
    assert_hitcount("query=anno:2000", 1)
    puts "Details: Checking doc is found with correct case in query, attribute search"
    assert_hitcount("query=AnnO:2000", 1)
    puts "Details: Checking no hits, attribute search"
    assert_hitcount("query=AnnO:2001", 0)

    puts "Details: Checking doc is found with all upper case in query, attribute search, nonalphanumeric char in query"
    assert_hitcount("query=ANNO:1985-12", 1)
    puts "Details: Checking doc is found with all lower case in query, attribute search, nonalphanumeric char in query"
    assert_hitcount("query=anno:1985-12", 1)
    puts "Details: Checking doc is found with correct case in query, attribute search, nonalphanumeric char in query"
    assert_hitcount("query=AnnO:1985-12", 1)
    puts "Details: Checking no hits, attribute search, nonalphanumeric char in query"
    assert_hitcount("query=AnnO:1985+12", 0)

    puts "Details: Checking doc is found with all upper case in query, attribute search, weighted set"
    assert_hitcount("query=YEARSET:2000", 1)
    puts "Details: Checking doc is found with all lower case in query, attribute search, weighted set"
    assert_hitcount("query=yearset:2000", 1)
    puts "Details: Checking doc is found with correct case in query, attribute search, weighted set"
    assert_hitcount("query=YearSet:2000", 1)
    puts "Details: Checking no hits, attribute search, weighted set"
    assert_hitcount("query=YearSet:2001", 0)

    puts "Details: Checking doc is found with all lower case in query, attribute search, weighted set, nonalphanumeric char in query"
    assert_hitcount("query=yearset:threethousand////one/lolz]]", 1)
  end

  def teardown
    stop
  end

end
