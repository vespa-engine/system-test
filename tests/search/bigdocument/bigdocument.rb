# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class BigDocument < IndexedStreamingSearchTest

  def timeout_seconds
    return 2500
  end

  def setup
    set_owner("aressem")
    deploy_app(SearchApp.new.sd(selfdir+"big.sd"))
    start
    @feed = dirs.tmpdir + "bigfeed.xml"
  end

  def gendocs
    size = [1000, 10000, 42, 17, 100000, 1400000, 200000, 17, 500001, 42]
    File.open(@feed, "w") do |file|
      10.times do |i|
        docid="id:test:big::doc#{i}"
        file.print("        <document type=\"big\" id=\"#{docid}\">\n")
        file.print("            <title>")
	(i+1).times { |j| file.print("#{j} ") }
        file.print("</title>\n")
        file.print("            <body>")
        size[i].times do |x|
          file.print("#{x} ");
        end
        file.print("</body>\n")
        file.print("        </document>\n")
      end
    end
  end

  def test_bigdocument
    puts "generate docs"
    gendocs
    puts "feed docs"
    feed_and_wait_for_docs("big", 10, :file => @feed, :timeout => 2500)
    assert_hitcount("query=title:0", 10)
    assert_hitcount("query=title:1",  9)
    assert_hitcount("query=title:2",  8)
    assert_hitcount("query=title:3",  7)
    assert_hitcount("query=title:4",  6)
    assert_hitcount("query=title:5",  5)
    assert_hitcount("query=title:6",  4)
    assert_hitcount("query=title:7",  3)
    assert_hitcount("query=title:8",  2)
    assert_hitcount("query=title:9",  1)

    assert_hitcount("query=body:0",      10)
    assert_hitcount("query=body:41",      8)
    assert_hitcount("query=body:999",     6)
    assert_hitcount("query=body:9999",    5)
    assert_hitcount("query=body:99999",   4)
    assert_hitcount("query=body:150000",  3)
    assert_hitcount("query=body:500000",  2)
  end

  def teardown
    stop
  end

end
