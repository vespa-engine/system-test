# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class LatencyEvents < IndexedSearchTest

  def nightly?
    true
  end

  def timeout_seconds
    return 1200
  end

  def setup
    set_owner("arnej")
    set_description("Test that the statistics query_latency and max_query latency appear in " +
      "the logarchive after a maximum of 5 minutes after queries have been performed. Their " +
      "values must be greater than 0.0")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_querylatencyevents
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")
    vespa.logserver.delete_vespalog

    endtime = Time.now.to_i + 75
    puts "Performing queries..."
    i = 0
    IO.foreach(selfdir + "music.1000.title.artist.song.queries.urlencoded") { |line|
      vespa.container.values.first.just_do_query("/search/?query="+line.chomp)
      i += 1
      if (i % 100) == 0
        puts "Performed #{i} queries"
      end
    }

    if Time.now.to_i < endtime
       sleep_secs = (endtime - Time.now.to_i)
       puts "Sleeping for #{sleep_secs} seconds, waiting for log entries..."
       sleep sleep_secs
    end

    logarchive = ""
    vespa.logserver.get_vespalog do |buf|
      logarchive += buf
    end
    matched = ""
    max_query_latency = 0.0
    query_latency = 0.0
    peak_qps = 0
    logarchive.each_line do |line|
      if line =~ /query_latency/
        matched += line
      elsif line =~ /peak_qps/
          peak_qps = peak_qps + 1
      end
      if line =~ /max_query_latency value=(\d+\.\d+)/
        if $1.to_f > 0.0
          max_query_latency = $1.to_f
        end
      end
      if line =~ /query_latency value=(\d+\.\d+)/
        if $1.to_f > 0.0
          query_latency = $1.to_f
        end
      end
    end

    puts "Logarchive lines containing the term 'query_latency':"
    puts matched
    assert(peak_qps > 0, "Found no event 'peak_qps'")
    assert(matched.length > 0, "No lines containing the term 'query_latency' found in the logarchive.")
    assert(max_query_latency > 0.0, "Max query latency was not greater than 0.0")
    assert(query_latency > 0.0, "Query latency was not greater than 0.0")
  end

  def teardown
    stop
  end

end

