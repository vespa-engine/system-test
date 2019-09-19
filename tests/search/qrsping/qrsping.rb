# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class QrsPing < IndexedSearchTest


  def setup
    set_owner("arnej")
    set_description("Check QRS pinging actually communicates with dispatch")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_qrsping
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml")

    puts "Stopping dispatch"
    stop_searchcluster
    # ping thread doesn't start at once, need to wait for it
    sleep 30
    puts "Running query"

    query = "/?query=blues"

    result = search_withtimeout(5, query)

    puts "Query result:"
    puts result.xmldata

    puts "Look for error code in result:"
    # Look for the code for no backends in service
    errorfound = false
    result.xml.elements.each("error") do |element|
      code = element.attributes["code"]
      if code == "0" || code == "10"
        errorfound = true
      end
    end
    assert errorfound
    assert_equal(0, result.hitcount)

    puts "Starting dispatch again:"
    start_searchcluster
    sleep 10
    puts "Running query after 10s sleep"

    wait_for_hitcount(query, 10)
    result = search_withtimeout(5, query)
    puts "Query result:"
    puts result.xmldata

    errorfound = false
    result.xml.elements.each("error") do |element|
      code = element.attributes["code"]
      #TODO On removing fdispatch code == "0" can not happen
      if code == "0" || code == "10"
        errorfound = true
      end
    end
    assert !errorfound
    assert_equal(10, result.hitcount)
  end

  def stop_searchcluster
    #TODO On removing topleveldispatch shall go
    vespa.search["search"].topleveldispatch["0"].stop
    vespa.search["search"].searchnode.values.each do |node|
      node.stop
    end
  end

  def start_searchcluster
    vespa.search["search"].topleveldispatch["0"].start
    vespa.search["search"].searchnode.values.each do |node|
      node.start
    end
  end

  def teardown
    stop
  end

end
