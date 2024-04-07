# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class QrsPing < IndexedOnlySearchTest

  def setup
    set_owner("arnej")
    set_description("Check QRS pinging actually communicates with search nodes")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_qrsping
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.json")

    puts "Stopping search nodes"
    stop_searchcluster

    puts "Running query"
    query = "/?query=blues&format=xml"
    result = search_with_timeout(5, query)
    puts "Query result:"
    puts result.xmldata

    puts "Look for error code in result:"
    # Look for the code for no backends in service
    errorfound = false
    result.xml.elements.each("error") do |element|
      code = element.attributes["code"]
      if code == "10"
        errorfound = true
      end
    end
    assert errorfound
    assert_equal(0, result.hitcount)

    puts "Starting dispatch again:"
    start_searchcluster
    wait_for_hitcount(query, 10)
    result = search_with_timeout(5, query)
    puts "Query result:"
    puts result.xmldata

    errorfound = false
    result.xml.elements.each("error") do |element|
      code = element.attributes["code"]
      if code == "10"
        errorfound = true
      end
    end
    assert !errorfound
    assert_equal(10, result.hitcount)
  end

  def stop_searchcluster
    vespa.search["search"].searchnode.values.each do |node|
      node.stop
    end
  end

  def start_searchcluster
    vespa.search["search"].searchnode.values.each do |node|
      node.start
    end
  end

  def teardown
    stop
  end

end
