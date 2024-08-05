# Copyright Vespa.ai. All rights reserved.
require 'document_set'
require 'indexed_streaming_search_test'

class IndexAddressing < IndexedStreamingSearchTest

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

    check_fields = [ 'artist', 'author', 'foobar', 'title', 'uri' ]
    assert_result("query=42",                    selfdir+"42.result.json", nil, check_fields)
    assert_result("query=42&hits=51",            selfdir+"42-all.result.json", nil, check_fields)
    assert_result("query=doc.42",                selfdir+"doc42.result.json", nil, check_fields)
    assert_result("query=42&sortspec=%2Bfoobar", selfdir+"fs.result.json", nil, check_fields)

    # hitting the cache should work too:

    assert_result("query=42",                    selfdir+"42.result.json", nil, check_fields)
    assert_result("query=42&hits=51",            selfdir+"42-all.result.json", nil, check_fields)
    assert_result("query=doc.42",                selfdir+"doc42.result.json", nil, check_fields)
    assert_result("query=42&sortspec=%2Bfoobar", selfdir+"fs.result.json", nil, check_fields)

  end

  def generate_doc(val, docs)
    @docid += 1
    idv = @docid
    mdh = idv % 1234
    bdh = (idv % 1423)+7

    doc = Document.new("music", "id:test:music::#{idv}")
    doc.add_field("title", "doc #{idv} hash #{mdh} val#{val}")
    doc.add_field("uri", "http://#{val}.yahoo.com/")
    doc.add_field("foobar", "http://#{2*val}.yahoo.com/")
    doc.add_field("artist", "#{idv} Rock Star")
    doc.add_field("popularity", idv)
    docs.add(doc)

    doc = Document.new("books", "id:test:books::#{idv}")
    doc.add_field("title", "doc #{idv} hash #{bdh} val#{val}")
    doc.add_field("uri", "http://#{val}.yahoo.com/")
    doc.add_field("foobar", "http://#{2*val+1}.yahoo.com/")
    doc.add_field("author", "Famous writer #{idv}")
    doc.add_field("myrank", 0.5+idv)
    docs.add(doc)
  end

  def generate_feed(numdocs)
    @docid = 0
    tmp_file = dirs.tmpdir+"docs-tmp.xml"
    docs = DocumentSet.new
    (1..numdocs).each { |val|
      generate_doc(val, docs)
    }
    docs.write_json(tmp_file)
    tmp_file
  end

  def teardown
    stop
  end

end
