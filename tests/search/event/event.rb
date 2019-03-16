# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Event < IndexedSearchTest

  #Description: Test query latency
  #Component: Statistics library and QRS integration

  def timeout_seconds
    # sleeps 300 seconds, everything else should be fast
    return  (300 + 120)
  end

  def setup
    @valgrind=false
    set_owner("arnej")
    add_bundle(selfdir + "QueryDepthSearcher.java")
    deploy_app(SearchApp.new.
                         container(Container.new.
                                             search(Searching.new.
                                                              chain(Searcher.new("com.yahoo.example.QueryDepthSearcher", "rawQuery", "transformedQuery"))).
                                             config(ConfigOverride.new("container.statistics").
                                                                   add("collectionintervalsec", 5).
                                                                   add("loggingintervalsec", 5))).
                         sd(selfdir+"music.sd"))
    start
  end

  def test_qrs_statistics
    puts "feeding 1 document"
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.xml")

    #restart qrserver
    vespa.qrserver["0"].stop
    vespa.qrserver["0"].start

    #run 10 queries
    run_ten_queries()

    #check that we have 10 queries
    assert_log_matches(Regexp.compile("Container.com.yahoo.statistics.Counter.*name=queries value=10"), 10)

    #check that at least one histogram is logged
    assert_log_matches(Regexp.compile("Container.com.yahoo.statistics.Value.*name=query_latency counts=\"\\\([1-9][0-9]*\\\)"), 1)

    #check the histogram from the plug-in is logged
    assert_log_matches(Regexp.compile("Container.com.yahoo.statistics.Value.*name=query_depth counts=\"\\\([0-9]*\\\)"), 1)
    #check the running counter from the plug-in is logged
    assert_log_matches(Regexp.compile("Container.com.yahoo.statistics.Value.*name=query_depth value=0.0"), 1)
  end

  def run_ten_queries
    puts "Running 10 queries"
    count = 0
    errorcount = 0
    while count < 10
      begin
        response = Net::HTTP.get_response(vespa.qrserver["0"].name, "/search/?query=#{count.to_s}", vespa.qrserver["0"].http_port)
        if response.code == "200"
          puts "Successfully run 1 query"
          count = count + 1
        end
      rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
        puts "Connection refused, trying again in 1 second"
        sleep 1
        errorcount = errorcount + 1
        if errorcount > 100
          assert(false, "Connection refused 100 times, giving up")
          break
        end
      end
    end
  end

  def teardown
    stop
  end

end
