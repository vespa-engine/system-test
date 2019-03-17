# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SearchDownWhileFeeding < IndexedSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test that we get an error when search is down while feeding but ok when search is up again")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_stop_search
    puts "Feeding when all is up"
    result = feedfile(selfdir+"music.xml")
    puts "1 RESULT *****************"
    puts result
    puts "1 ************************"
    assert(result.index("ok: 10"))

    puts "Stopping one searchnode"
    vespa.search["search"].first.stop

    puts "Feeding with searchnode down"

    result = feedfile(selfdir+"music.xml", { :exceptiononfailure => false, :abortonerror => "no", :timeout => 10 })

    puts "2 RESULT *****************"
    puts result
    puts "2 ************************"
    # only with --progress yes # assert(result.index("Lost: 10"))

    assert(result.index("failed: 10"))

    puts "Starting searchnode again"
    vespa.search["search"].first.start

    result = feedfile(selfdir+"music.xml", :exceptiononfailure => false)
    puts "3 RESULT *****************"
    puts result
    puts "3 ************************"
    assert(result.index("ok: 10"))
  end

  def teardown
    stop
  end

end
