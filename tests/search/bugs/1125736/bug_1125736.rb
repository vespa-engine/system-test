# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bug_1125736 < IndexedSearchTest

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"jpexact.sd"))
    start
  end

  def compare(query, file)
    puts "compare '#{query}' with '#{file}'"
    # run all queries twice to check caching
    assert_result(query, selfdir+file, "uri")
    assert_result(query, selfdir+file, "uri")
    # explicitly avoid cache
    assert_result(query + "&nocache", selfdir+file, "uri")
    # then try normal again
    assert_result(query, selfdir+file, "uri")
  end


  def disabled_test_exact_doublewidth
    feed_and_wait_for_docs("jpexact", 3, :file => selfdir+"3-dblw-docs.xml")

    # "Query: basic test"
    compare("query=test", "q1.result")

    # "Query: singlewidth title"
    compare("query=OS", "q2.result")

    # "Query: doublewidth title"
    compare("query=%EF%BC%AF%EF%BC%B3&language=ja", "q2.result")

    # "os"   == %EF%BC%AF%EF%BC%B3
    # "sony" == %EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9

    # "Query: singlewidth exact"
    compare("query=exactone:%22sngw+SONY%22", "q.exact-sngw.sony-result")
    compare("query=exacttwo:%22sngw+SONY%22", "q.exact-sngw.sony-result")
    compare("query=exactthree:%22sngw+SONY%22", "q.exact-sngw.sony-result")

    compare("query=mexactone:sngw.SONY", "q.exact-sngw.sony-result")
    compare("query=mexacttwo:sngw.SONY", "q.exact-sngw.sony-result")
    compare("query=mexactthree:sngw.SONY", "q.exact-sngw.sony-result")

    compare("query=mexactone:%22SONY+sngw%22", "q.exact-sngw.sony-result")
    compare("query=mexacttwo:%22SONY+sngw%22", "q.exact-sngw.sony-result")
    compare("query=mexactthree:%22SONY+sngw%22", "q.exact-sngw.sony-result")

    # QRS takes care of normalizing query:
    compare("query=exactone:%22sngw+%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9%22", "q.exact-sngw.sony-result")
    compare("query=exacttwo:%22sngw+%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9%22", "q.exact-sngw.sony-result")
    compare("query=exactthree:%22sngw+%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9%22", "q.exact-sngw.sony-result")

    # "Query: single word doublewidth exact"

    compare("query=exactone:os", "q.exact-os-result")
    compare("query=exacttwo:os", "q.exact-os-result")
    compare("query=exactthree:os", "q.exact-os-result")
    compare("query=mexactone:os", "q.exact-os-result")
    compare("query=mexacttwo:os", "q.exact-os-result")
    compare("query=mexactthree:os", "q.exact-os-result")

    compare("query=exactone:%EF%BC%AF%EF%BC%B3", "q.exact-os-result")
    compare("query=exacttwo:%EF%BC%AF%EF%BC%B3", "q.exact-os-result")
    compare("query=exactthree:%EF%BC%AF%EF%BC%B3", "q.exact-os-result")
    compare("query=mexactone:%EF%BC%AF%EF%BC%B3", "q.exact-os-result")
    compare("query=mexacttwo:%EF%BC%AF%EF%BC%B3", "q.exact-os-result")
    compare("query=mexactthree:%EF%BC%AF%EF%BC%B3", "q.exact-os-result")

    # "Query: doublewidth exact"
    compare("query=exactone:sony.dblw", "q.exact-sony.dblw-result")
    compare("query=exacttwo:sony.dblw", "q.exact-sony.dblw-result")
    compare("query=exactthree:sony.dblw", "q.exact-sony.dblw-result")
    compare("query=mexactone:sony.dblw", "q.exact-sony.dblw-result")
    compare("query=mexacttwo:sony.dblw", "q.exact-sony.dblw-result")
    compare("query=mexactthree:sony.dblw", "q.exact-sony.dblw-result")
    compare("query=mexactone:dblw.sony", "q.exact-sony.dblw-result")
    compare("query=mexacttwo:dblw.sony", "q.exact-sony.dblw-result")
    compare("query=mexactthree:dblw.sony", "q.exact-sony.dblw-result")

    compare("query=exactone:%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9.dblw", "q.exact-sony.dblw-result")
    compare("query=exacttwo:%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9.dblw", "q.exact-sony.dblw-result")
    compare("query=exactthree:%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9.dblw", "q.exact-sony.dblw-result")
    compare("query=mexactone:%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9.dblw", "q.exact-sony.dblw-result")
    compare("query=mexacttwo:%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9.dblw", "q.exact-sony.dblw-result")
    compare("query=mexactthree:%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9.dblw", "q.exact-sony.dblw-result")
    compare("query=mexactone:dblw.%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9", "q.exact-sony.dblw-result")
    compare("query=mexacttwo:dblw.%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9", "q.exact-sony.dblw-result")
    compare("query=mexactthree:dblw.%EF%BC%B3%EF%BC%AF%EF%BC%AE%EF%BC%B9", "q.exact-sony.dblw-result")

  end

  def teardown
    stop
  end
end
