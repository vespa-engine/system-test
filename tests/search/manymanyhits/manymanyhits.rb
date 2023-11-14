# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'environment'

class ManyManyHits < IndexedSearchTest

  def initialize(*args)
    super(*args)
  end

  def timeout_seconds
    3600
  end

  def setup
    set_owner("arnej")
    set_description("Test with 'big' resultsets")
  end

  def self.final_test_methods
    ["test_manymanyhits"]
  end

  def test_manymanyhits
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").
                   search_dir(selfdir + "search"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")

    timeout=30
    query = "/?query=mid:2&hits=10000&nocache&format=xml"

    puts "running query once..."
    result = save_result_with_timeout(timeout, query, "#{Environment.instance.vespa_home}/tmp/mmhresult.1.xml")
    puts "got #{result.xmldata.length} bytes"

    puts "running query twice..."
    result = save_result_with_timeout(timeout, query, "#{Environment.instance.vespa_home}/tmp/mmhresult.2.xml")
    puts "got #{result.xmldata.length} bytes"
    diff1 = `diff #{Environment.instance.vespa_home}/tmp/mmhresult.1.xml #{Environment.instance.vespa_home}/tmp/mmhresult.2.xml`
    puts "diff mmhresult.1.xml vs mmhresult.2.xml: #{diff1}"

    puts "running query thrice..."
    result = save_result_with_timeout(timeout, query, "#{Environment.instance.vespa_home}/tmp/mmhresult.3.xml")
    puts "got #{result.xmldata.length} bytes"
    diff2 = `diff #{Environment.instance.vespa_home}/tmp/mmhresult.2.xml #{Environment.instance.vespa_home}/tmp/mmhresult.3.xml`
    puts "diff mmhresult.2.xml vs mmhresult.3.xml: #{diff2}"

    hitcount = 0
    # Note: Trying to actually parse the XML would crash Ruby version
    # available when writing this test
    xmldata = result.xmldata
    offset = xmldata.index("<hit ")
    while offset do
      hitcount += 1
      # Offset 5 to index = "<hit ".length
      offset = xmldata.index("<hit ", offset+5)
    end
    puts "counted #{hitcount} hits"
    assert_equal(10000, hitcount)
    assert_equal("", diff1)
    assert_equal("", diff2)
  end

  def test_manymanyhitsbutno
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 10000, :file => SEARCH_DATA+"music.10000.xml")

    timeout=30
    query = "/?query=mid:2&hits=10000&nocache&format=xml"

    search_with_timeout(timeout, query)
    search_with_timeout(timeout, query)
    search_with_timeout(timeout, query)
    result = search_with_timeout(timeout, query)
    hitcount = 0
    # Note: Trying to actually parse the XML would crash Ruby version
    # available when writing this test
    offset = result.xmldata.index("<hit ")
    while offset do
      hitcount += 1
      # Offset 5 to index = "<hit ".length
      offset = result.xmldata.index("<hit ", offset+5)
    end
    # Should get an error message instead of hits
    assert_equal(0, hitcount)
  end

  def teardown
    stop
  end

end
