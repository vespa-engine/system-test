# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SelectSummary < IndexedStreamingSearchTest

  def setup
    set_owner("bratseth")
    set_description("Test selecting summary class by name")
  end

  def timeout_seconds
    return 1800
  end

  def test_selectsummary_twophase
    puts "Details: Setting up twophase config"
    deploy_app(SearchApp.new.sd(selfdir + "selsum.sd"))
    start
    feed_and_wait_for_docs("selsum", 1, :file => selfdir + "selsum.json")
    puts "# sanity check"
    assert_hitcount("query=sddocname:selsum", 1)

    regexp = /"foo"|"bar"/
    puts "Details: Running query tests (twophase)"
    assert_result("query=test&summary=foosum", selfdir + "foo.result.json", nil, [ 'foo', 'bar' ])
    assert_result("query=test&summary=barsum", selfdir + "bar.result.json", nil, [ 'foo', 'bar' ])
    assert_result("query=test&summary=barsum", selfdir + "bar.result.json", nil, [ 'foo', 'bar' ])
    assert_result("query=test&summary=foosum", selfdir + "foo.result.json", nil, [ 'foo', 'bar' ])
  end

  def test_selectsummary_indexaddressing
    puts "Details: index addressing, common feed"
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new("music").sd(selfdir+"music.sd")).
               cluster(SearchCluster.new("books").sd(selfdir+"books.sd")))
    start
    feed_and_wait_for_docs("music", 5, :file => selfdir + "music-and-books-first.json", :cluster => "music")
    wait_for_hitcount("query=sddocname:books", 6)
    assert_hitcount("query=sddocname:music", 5)

    puts "Query: Match all documents in both indexes"
    assert_hitcount("query=(sddocname:books+sddocname:music+)&summary=foosum&nocache", 11)

    puts "Query: Match some documents in music"
    comp("query=2&search=music&summary=foosum", "indexaddressing.2.result.json", nil, ["relevancy", "title", "nicefoo", "artist", "summaryfeatures"])
    puts "Query: Match some documents in books"
    comp("query=2&search=books&summary=foosum", "indexaddressing.3.result.json")
    puts "Query: Blend matches from both"
    comp("query=2&summary=foosum",              "indexaddressing.4.result.json", "title", ["relevancy", "title", "nicefoo", "artist", "summaryfeatures", "valfoo", "author"])

    vespa.stop_base
    # note: no vespa.clean, so the clusters will still have docs etc.
    # after the change
    puts "Details: index addressing, separate feeds"
    deploy_app(SearchApp.new.
               cluster(SearchCluster.new("music").sd(selfdir+"music.sd")).
               cluster(SearchCluster.new("books").sd(selfdir+"books.sd")))
    vespa.start_base

    wait_until_ready

    wait_for_hitcount("query=sddocname:books", 6)
    wait_for_hitcount("query=sddocname:music", 5)
    assert_hitcount("query=(sddocname:books+sddocname:music+)&summary=foosum&nocache", 11)

    feed_and_wait_for_docs("music", 0, :file => selfdir + "music-and-books-first.remove.music.json", :cluster => "music")
    feed_and_wait_for_docs("music", 4, :file => selfdir + "music-second.json", :cluster => "music")
    puts "# sanity checks"
    assert_hitcount("query=sddocname:books&nocache", 6)
    assert_hitcount("query=sddocname:music&nocache", 4)
    assert_hitcount("query=(sddocname:books+sddocname:music+)&summary=foosum&nocache", 10)

    puts "Query: should be no changes in books"
    comp("query=2&search=books&summary=foosum", "indexaddressing.3.result.json")
    puts "Query: Match the new docs in music"
    comp("query=2&search=music&summary=foosum", "indexaddressing.2b.result.json", nil, ["relevancy", "title", "nicefoo", "artist", "summaryfeatures"])

    feed_and_wait_for_docs("books", 0, :file => selfdir + "music-and-books-first.remove.books.json", :cluster => "books")
    feed_and_wait_for_docs("books", 7, :file => selfdir + "books-second.json", :cluster => "books")

    puts "# sanity checks"
    assert_hitcount("query=sddocname:music&nocache", 4)
    assert_hitcount("query=sddocname:books&nocache", 7)
    assert_hitcount("query=(sddocname:books+sddocname:music+)&summary=foosum&nocache", 11)

    puts "Query: Match all new docs in books"
    comp("query=sddocname:books&search=books&summary=foosum", "indexaddressing.3b.result.json", "title")
    puts "Query: Match the new docs in music"
    comp("query=2&search=music&summary=foosum", "indexaddressing.2b.result.json", nil, ["relevancy", "title", "nicefoo", "artist", "summaryfeatures"])
    puts "Query: Blend matches from both"
    comp("query=2&summary=foosum",              "indexaddressing.5.result.json", "title", ["relevancy", "title", "nicefoo", "artist", "summaryfeatures", "valfoo", "author"])
  end


  def comp(q, r, sf=nil, compareFields=nil)
    assert_result(q, selfdir + r, sf, compareFields)
    assert_result(q, selfdir + r, sf, compareFields) # Repeat to hit cache
    assert_result(q + "&nocache", selfdir + r, sf, compareFields)
  end

  def test_selectsummary_inherit_abstract
    puts "Details: Using simple inherit (abstract base)"

    dir = selfdir + "simpleinherit_abstract_nobasesearch/schemas/"
    deploy_app(SearchApp.new.
               sd(dir + "base_nosearch.sd").
               sd(dir + "derived.sd"))
    start
    feed_and_wait_for_docs("derived", 2, :file => selfdir + "testsimpleinheritance.2.json")
    puts "# sanity checks"
    assert_hitcount("query=sddocname:derived", 2)

    puts "Queries with foo summary class"
    comp("query=field1:f1&summary=foosum",                  "si1f.result.json", "field1")
    comp("query=field1:f1&search=derived&summary=foosum",   "si1f.result.json", "field1")

    puts "Queries with bar summary class"
    comp("query=field2:f2d2&summary=barsum",                "si2b.result.json")
    comp("query=field2:f2d2&search=derived&summary=barsum", "si2b.result.json")

    puts "Queries with default summaryclass"
    comp("query=field1:f1",                  "si1.result.json", "field1")
    comp("query=field2:f2d2",                "si2.result.json")
    comp("query=field1:f1&search=derived",   "si1.result.json", "field1")
    comp("query=field2:f2d2&search=derived", "si2.result.json")

  end

  def test_simpleinherit
    puts "Details: Using simple inherit"
    dir = selfdir + "simpleinherit_basesearch/schemas/"
    deploy_app(SearchApp.new.
               sd(dir + "base.sd").
               sd(dir + "derived.sd"))
    start
    feed_and_wait_for_docs("derived", 2, :file => selfdir + "testsimpleinheritance.2.json")
    puts "# sanity checks"
    assert_hitcount("query=sddocname:derived", 2)

    puts "Queries with default summaryclass"
    comp("query=field1:f1",                  "si1.result.json", "field1", ["field1","field2","field3","field4","field5","url"])
    comp("query=field1:f1&search=derived",   "si1.result.json", "field1", ["field1","field2","field3","field4","field5","url"])
    comp("query=field1:f1&search=base",      "empty.result.json", "field1", ["field1","field2","field3","field4","field5","url"])

    # We are not getting the uri field as a duplicate for url with logical indices, so specify
    # the fields to compare to avoid comparing uri
    comp("query=field2:f2d2",                "si2.result.json", nil, ["field1","field2","field3","field4","field5","url"])
    comp("query=field2:f2d2&search=derived", "si2.result.json", nil, ["field1","field2","field3","field4","field5","url"])
    comp("query=field2:f2d2&search=base",    "empty.result.json", nil, ["field1","field2","field3","field4","field5","url"])

    puts "Queries with foo summary class"
    comp("query=field1:f1&summary=foosum",                  "si1f.result.json", "field1")
    comp("query=field1:f1&search=base&summary=foosum",      "empty.result.json", "field1")
    comp("query=field1:f1&search=derived&summary=foosum",   "si1f.result.json", "field1")

    puts "Queries with bar summary class"
    comp("query=field2:f2d2&summary=barsum",                "si2b.result.json")
    comp("query=field2:f2d2&search=base&summary=barsum",    "empty.result.json")
    comp("query=field2:f2d2&search=derived&summary=barsum", "si2b.result.json")

  end

  def test_selectsummary_multipleinherit
    puts "Details: Using multiple inherit"

    dir = selfdir + "multipleinherit/schemas/"
    deploy_app(SearchApp.new.
               sd(dir + "base1.sd").
               sd(dir + "base2.sd").
               sd(dir + "derived2.sd").
               sd(dir + "derived3.sd"))
    start
    feed_and_wait_for_docs("derived2", 1, :file => selfdir + "testmultiinheritance.3.json", :cluster => "logical")
    puts "# sanity checks"

    assert_hitcount("query=sddocname:derived2", 1)
    wait_for_hitcount("query=sddocname:base1", 1)
    wait_for_hitcount("query=sddocname:base2", 1)

    puts "Query: Test with default summary class"
    comp("query=sddocname:base1",    "mib1.result.json", "sddocname")
    comp("query=sddocname:base2",    "mib2.result.json", "sddocname")
    comp("query=sddocname:derived2", "mid2.result.json", "sddocname")
    comp("query=sddocname:derived3", "mid3.result.json", "sddocname")
    comp("query=common",             "mic.result.json",  "sddocname")

    puts "Query: Test with foo summary class"
    comp("query=sddocname:base1&summary=foosum", "mib1-foo.result.json", "sddocname")
    comp("query=sddocname:base2&summary=foosum", "mib2-foo.result.json", "sddocname")
    comp("query=common&summary=foosum",          "mic-foo.result.json",  "sddocname")

    puts "Query: Test with bar summary class"
    comp("query=sddocname:base1&summary=barsum", "mib1-bar.result.json")
    comp("query=sddocname:base2&summary=barsum", "mib2-bar.result.json", "sddocname")

    if is_streaming
      comp("query=common&summary=barsum", "mic-bar.result.streaming.json", "relevancy")
    else
      comp("query=common&summary=barsum", "mic-bar.result.json", "relevancy")
    end

    puts "Query: Test with quux summary class"
    if is_streaming
      comp("query=common&summary=quuxsum", "mic-quux.result.streaming.json", "relevancy")
    else
      comp("query=common&summary=quuxsum", "mic-quux.result.json", "relevancy")
    end

    puts "Query: Test that common is present, searching derived2 only"
    comp("query=common&search=derived2&summary=foosum", "testmultiinherit.result.json", "sddocname")
  end

  def teardown
    stop
  end

end
