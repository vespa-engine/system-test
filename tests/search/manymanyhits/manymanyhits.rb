# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'environment'

class ManyManyHits < IndexedStreamingSearchTest

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
    len1 = result.xmldata.length

    puts "running query twice..."
    result = save_result_with_timeout(timeout, query, "#{Environment.instance.vespa_home}/tmp/mmhresult.2.xml")
    puts "got #{result.xmldata.length} bytes"
    len2 = result.xmldata.length
    unless is_streaming
      diff1 = `diff #{Environment.instance.vespa_home}/tmp/mmhresult.1.xml #{Environment.instance.vespa_home}/tmp/mmhresult.2.xml`
      puts "diff mmhresult.1.xml vs mmhresult.2.xml: #{diff1}"
    end

    puts "running query thrice..."
    result = save_result_with_timeout(timeout, query, "#{Environment.instance.vespa_home}/tmp/mmhresult.3.xml")
    puts "got #{result.xmldata.length} bytes"
    len3 = result.xmldata.length
    unless is_streaming
      diff2 = `diff #{Environment.instance.vespa_home}/tmp/mmhresult.2.xml #{Environment.instance.vespa_home}/tmp/mmhresult.3.xml`
      puts "diff mmhresult.2.xml vs mmhresult.3.xml: #{diff2}"
    end

    puts "counted #{result.hitcount} hits"
    assert_equal(10000, result.hitcount)
    unless is_streaming
      assert_equal("", diff1)
      assert_equal("", diff2)
    end
    assert_equal(len1, len2)
    assert_equal(len1, len3)
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
    assert_equal(0, result.hitcount)
  end

  def teardown
    stop
  end

end
