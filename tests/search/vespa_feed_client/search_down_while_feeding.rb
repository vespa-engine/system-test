# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class SearchDownWhileFeeding < IndexedStreamingSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test that we get an error when search is down while feeding but ok when search is up again")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_stop_search
    puts "Feeding when all is up"
    result = feedfile(selfdir+"music.json")
    puts "1 RESULT *****************"
    puts result
    puts "1 ************************"
    assert_match(/ok: 10/, result)

    puts "Stopping one searchnode"
    vespa.search["search"].first.stop
    sleep(10)

    puts "Feeding with searchnode down"

    result = feedfile(selfdir+"music.json", { :exceptiononfailure => false, :timeout => 10 })

    puts "2 RESULT *****************"
    puts result
    puts "2 ************************"
    # only with --progress yes # assert(result.index("Lost: 10"))

    assert_match(/failed: 10/, result)

    puts "Starting searchnode again"
    vespa.search["search"].first.start

    result = feedfile(selfdir+"music.json", :exceptiononfailure => false)
    puts "3 RESULT *****************"
    puts result
    puts "3 ************************"
    assert_match(/ok: 10/, result)
  end

  def teardown
    stop
  end

end
