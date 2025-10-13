# Copyright Vespa.ai. All rights reserved.
require 'document_set'
require 'indexed_streaming_search_test'

class BigDocument < IndexedStreamingSearchTest

  def timeout_seconds
    return 2500
  end

  def setup
    set_owner("aressem")
    deploy_app(SearchApp.new.sd(selfdir+"big.sd"))
    start
    @feed = dirs.tmpdir + "bigfeed.json"
  end

  def gendocs
    docs = DocumentSet.new
    size = [1000, 10000, 42, 17, 100000, 1400000, 200000, 17, 500001, 42]

    10.times do |i|
      doc = Document.new("id:test:big::doc#{i}")

      title = ""
      (i+1).times { |j| title << "#{j} " }
      doc.add_field("title", title)

      body = ""
      size[i].times do |x|
        body << "#{x} "
      end
      doc.add_field("body", body)

      docs.add(doc)
    end
    docs.write_json(@feed)
  end

  def check(q, n)
    query = "query=#{q}"
    assert_hitcount_with_timeout(20.0, query, n)
  end

  def test_bigdocument
    puts "generate docs"
    gendocs
    puts "feed docs"
    feed_and_wait_for_docs("big", 10, :file => @feed, :timeout => 2500)
    check("title:0", 10)
    check("title:1",  9)
    check("title:2",  8)
    check("title:3",  7)
    check("title:4",  6)
    check("title:5",  5)
    check("title:6",  4)
    check("title:7",  3)
    check("title:8",  2)
    check("title:9",  1)

    check("body:0",      10)
    check("body:41",      8)
    check("body:999",     6)
    check("body:9999",    5)
    check("body:99999",   4)
    check("body:150000",  3)
    check("body:500000",  2)
  end

  def teardown
    stop
  end

end
