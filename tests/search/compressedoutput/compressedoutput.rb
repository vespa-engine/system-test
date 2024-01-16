# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'
require 'resultset'


class CompressedOutput < IndexedStreamingSearchTest
  def setup
    set_owner("bjorncs")
    set_description("Test that checks if compression works")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def decompress(input)
    output = ""
    pipe = IO.popen("gzip -d -f","w+")
    pipe.write input
    pipe.close_write
    return pipe.read

  end

  def searchComp(searchstring)
    header= {"Accept-Encoding" => "gzip"}
    compdata = search(searchstring+"&compress", 0, header)
  end

  def test_compression
    feed(:file => selfdir+"largefile.1.xml")
    wait_for_hitcount("query=sddocname:music&hits=0", 2)

    longsearchstring = "/?query=title:First"
    wait_for_hitcount(longsearchstring, 1)

    #First get the uncompressed
    uncompresult = search(longsearchstring)
    uncomp = uncompresult.xmldata

    puts "Size uncompressed: " + uncomp.length.to_s

    #Then check the compressed
    comp = searchComp(longsearchstring).xmldata
    compsize = comp.length
    puts "Size compressed: " + compsize.to_s
    assert(compsize < uncomp.length*0.9)

    #Assert that the number of results is the same
    compresult = Resultset.new(decompress(comp), longsearchstring)
    assert(compresult.hitcount == uncompresult.hitcount)
  end

  def teardown
    stop
  end
end

