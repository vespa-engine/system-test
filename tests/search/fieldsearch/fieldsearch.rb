# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class FieldSearch < IndexedSearchTest

  def setup
    set_owner("yngve")
    set_description("Field search for text and string, and range search for integers.")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def compare(query, file, field)
    # run all queries twice to check caching
    assert_field(query, selfdir+file, field, true)
    assert_field(query, selfdir+file, field, true)
    # explicitly avoid cache
    assert_field(query + "&nocache", selfdir+file, field, true)
    # then try normal again
    assert_field(query, selfdir+file, field, true)
  end

  def test_medium_advanced
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
    puts "Waiting for result with docsum"
    assert_result_with_timeout(30, 'query=rock%20year:%5B1999%3B2002%5D&hits=100&type=all', selfdir + "1.result.json", "surl", ["surl"])

    puts "Query: rock + range of years"
    compare('query=rock%20year:%5B1999%3B2002%5D&hits=100&type=all', "1.result.json", "surl")

    puts "Query: range of years - single year in range"
    compare('query=year:%5B1970%3B1973%5D%20-year:1972&hits=100&type=all', "2.result.json", "surl")

    puts "Query: rock - rock in title"
    compare('query=rock%20-title:rock&hits=100&type=all', "3.result.json", "surl")

    puts "Query: yellow in song - yellow in title"
    compare('query=song:yellow%20-title:yellow&type=all', "4.result.json", "surl")

    puts "Query: YQL year range using ># and <#"
    compare('query=select+%2A+from+sources+%2A+where+year+%3E+0%20and%20year+%3C+1930%3B&type=yql', "5.result.json", "surl")

    puts "Query: as previous query but using [# ; #]"
    compare('query=year:%5B1%3B1929%5D&type=all', "6.result.json", "surl")

    puts "Query: searching for integer in text-fields"
    compare('query=title:101%20-song:101&type=all', "7.result.json", "surl")
  end

  def teardown
    stop
  end

end
