# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class BenchmarkingHeaders < IndexedStreamingSearchTest


  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_benchmarkingheaders
    query = "query=sddocname:music&nocache&tracelevel=3"
    requestheader = { "X-Yahoo-Vespa-Benchmarkdata" => "1" }
    result = search(query, 0, requestheader)
    puts "First query... Result code: #{result.responsecode} "

    result = search(query, 0, requestheader)
    puts "Second query... Result code: #{result.responsecode} "

    result = search(query, 0, requestheader)
    puts "Third query... Result code: #{result.responsecode} "

    result = search(query, 0, requestheader)
    puts "Fourth query... Result code: #{result.responsecode} "

    puts "Actual test"

    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json", :timeout => 240)

    responseheaders = { "X-Yahoo-Vespa-NumHits" => "10",
                        "X-Yahoo-Vespa-NumFastHits" => "10",
                        "X-Yahoo-Vespa-TotalHitCount" => "10",
                        "X-Yahoo-Vespa-QueryHits" => "10"}
    assert_hitcount(query, 10)
    assert_httpresponse(query, {}, 200)
    assert_httpresponse(query, requestheader, 200, responseheaders)

    requestheader_coverage = { "X-Yahoo-Vespa-Benchmarkdata" => "1",
                               "X-Yahoo-Vespa-Benchmarkdata-Coverage" => "1"
    }
    responseheaders_coverage = { "X-Yahoo-Vespa-NumHits" => "10",
                        "X-Yahoo-Vespa-NumFastHits" => "10",
                        "X-Yahoo-Vespa-TotalHitCount" => "10",
                        "X-Yahoo-Vespa-QueryHits" => "10",
                        "X-Yahoo-Vespa-NodesSearched" => "1"}
    assert_httpresponse(query, requestheader_coverage, 200, responseheaders_coverage)
  end

  def teardown
    stop
  end


end
