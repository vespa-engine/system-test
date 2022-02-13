# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class IndexAddressing < IndexedSearchTest

  def dwrite(tmp, val)
    @docid += 1
    idv = @docid
    mdh = idv % 1234
    bdh = (idv % 1423)+7
    tmp << "<document type=\"music\" documentid=\"id:test:music::#{idv}\">\n"
    tmp << "  <title>doc #{idv} hash #{mdh} val#{val}</title>\n"
    tmp << "  <uri>http://#{val}.yahoo.com/</uri>\n"
    tmp << "  <foobar>http://#{2*val}.yahoo.com/</foobar>\n"
    tmp << "  <artist>#{idv} Rock Star</artist>\n"
    tmp << "  <popularity>#{idv}</popularity>\n"
    tmp << "</document>\n"

    tmp << "<document type=\"books\" documentid=\"id:test:books::#{idv}\">\n"
    tmp << "  <title>doc #{idv} hash #{bdh} val#{val}</title>\n"
    tmp << "  <uri>http://#{val}.yahoo.com/</uri>\n"
    tmp << "  <foobar>http://#{2*val+1}.yahoo.com/</foobar>\n"
    tmp << "  <author>Famous writer #{idv}</author>\n"
    tmp << "  <myrank>#{0.5+idv}</myrank>\n"
    tmp << "</document>\n"
  end

  def generate_feed(numdocs)
    @docid = 0
    tmp_file = dirs.tmpdir+"docs-tmp.xml"
    File.open(tmp_file, "w") do |tmp|
      (1..numdocs).each { |val| dwrite(tmp, val) }
    end
    return tmp_file
  end

  def setup
    set_owner("arnej")
    set_description("Get hits from a specific (or all) indexes, blending")
    deploy_app(SearchApp.new.cluster(
                        SearchCluster.new("music").
                        sd(selfdir + "music.sd")).
                      cluster(
                        SearchCluster.new("books").
                        sd(selfdir + "books.sd")))
    start
  end

  def test_index_addressing
    file = generate_feed(10000)
    feed_and_wait_for_docs("music", 10000, :file => file)

    wait_for_hitcount("query=sddocname:books", 10000)
    puts "Query: Match all documents in both indexes"
    wait_for_hitcount("query=sddocname:music+sddocname:books&type=any", 20000)

    puts "Query: Match all documents in music"
    assert_hitcount("query=sddocname:music", 10000)
    assert_hitcount("query=sddocname:music+sddocname:books&type=any&search=music", 10000)

    puts "Query: Match all documents in books"
    assert_hitcount("query=sddocname:books", 10000)
    assert_hitcount("query=sddocname:music+sddocname:books&type=any&search=books", 10000)

    puts "Query: Blend matches from both"

    assert_result("query=42",                    selfdir+"42.result.json")
    assert_result("query=42&hits=51",            selfdir+"42-all.result.json")
    assert_result("query=doc.42",                selfdir+"doc42.result.json")
    assert_result("query=42&sortspec=%2Bfoobar", selfdir+"fs.result.json")

    # hitting the cache should work too:

    assert_result("query=42",                    selfdir+"42.result.json")
    assert_result("query=42&hits=51",            selfdir+"42-all.result.json")
    assert_result("query=doc.42",                selfdir+"doc42.result.json")
    assert_result("query=42&sortspec=%2Bfoobar", selfdir+"fs.result.json")

  end

  def teardown
    stop
  end

end
