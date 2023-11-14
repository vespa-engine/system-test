# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document'
require 'document_set'
require 'indexed_search_test'

class LargeText < IndexedSearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_large_text
    arr = [ ]
    arr << time_feed(10000)
    arr << time_feed(20000)
    arr << time_feed(40000)
    arr << time_feed(80000)
    arr << time_feed(160000)
    arr << time_feed(320000)
    arr << time_feed(640000)
    arr << time_feed(1280000)
    puts "rate = " + arr.join(" ")
  end

  def time_feed(num_tokens)
    doc = Document.new("test", "id:ns:test::")
    doc.add_field("my_str", (0..num_tokens - 1).map{ |i| "t#{i}" }.join(" "))

    docs = DocumentSet.new()
    docs.add(doc)

    file = "#{dirs.tmpdir}/input#{num_tokens}.xml";
    docs.write_xml(file)

    time = Time.now.getutc
    feed_and_wait_for_docs("test", 1, :file => file, 
                           :timeout => timeout_seconds)
    secs = Time.now.getutc - time
    rate = num_tokens / secs

    wait_for_hitcount("query=my_str:t" + (0).to_s, 1)
    wait_for_hitcount("query=my_str:t" + (num_tokens / 2).to_s, 1)
    wait_for_hitcount("query=my_str:t" + (num_tokens - 1).to_s, 1)

    puts "#{num_tokens} tokens => #{secs} secs, #{rate} rate"
    return rate
  end

  def timeout_seconds
    return 900
  end

  def teardown
    stop
  end

end
