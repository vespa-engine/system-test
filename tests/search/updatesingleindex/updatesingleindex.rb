# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class UpdateSingleIndex < IndexedSearchTest

  def setup
    set_owner("yngve")
  end

  def test_indexaddressing
    puts "Description: (Multinode): Update one datatype, only this will be reindexed"
    puts "Component: Config, Storage, Indexing etc"
    puts "Feature: Storage selection and data feeding"

    puts "Details: index addressing, common feed"
    deploy_app(SearchApp.new.cluster(
                        SearchCluster.new("music").sd(selfdir + "music.sd")).
                      cluster(
                        SearchCluster.new("books").sd(selfdir + "books.sd")))
    vespa.start
    wait_until_ready
    feed_and_wait_for_docs("music", 10000, :file => selfdir + "testlogicaladv.20000.xml", :clusters => ["music", "books"])
    wait_for_hitcount("query=sddocname:music&search=music", 10000)
    wait_for_hitcount("query=sddocname:books&search=books", 10000)

    puts "Query: Match all documents in both indexes"
    assert_hitcount("query=(sddocname:books+sddocname:music+)", 20000)
    puts "Query: Match all documents in music"
    assert_hitcount("query=sddocname:music&search=music", 10000)
    puts "Query: Match all documents in books"
    assert_hitcount("query=sddocname:books&search=books", 10000)
    puts "Query: Blend matches from both"
    assert_result("query=world+modern",
                  selfdir + "indexaddressing.4.result.json",
                  "title", [ "title", "author", "artist", "mid" ])


    vespa.stop_base
    # note: no vespa.clean, so the clusters will still have docs etc.
    # after the change
    puts "Details: index addressing, separate feeds"
    deploy_app(SearchApp.new.cluster(
                        SearchCluster.new("music").sd(selfdir + "music.sd")).
                      cluster(
                        SearchCluster.new("books").sd(selfdir + "books.sd")))
    vespa.start_base

    wait_until_ready

    wait_for_hitcount("query=sddocname:music&search=music", 10000)
    wait_for_hitcount("query=sddocname:books&search=books", 10000)

    feed_and_wait_for_docs("music", 0, :file => selfdir + "testlogicaladv.20000.remove.music.xml", :clusters => ["music", "books"], :encoding => "iso-8859-1")
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA+"music.10.xml", :cluster => "music")
    wait_for_hitcount("query=sddocname:music&search=music", 10)

    puts "Query: Match the 10 new docs in music"
    assert_result("query=sddocname:music&search=music",
                   selfdir + "indexaddressing.2b.result.json",
                  "artist",
                  [ "author", "artist", "mid" ])
    puts "Query: Match all documents in books"
    assert_hitcount("query=sddocname:books&search=books", 10000)
    feed_and_wait_for_docs("books", 0, :file => selfdir + "testlogicaladv.20000.remove.books.xml", :clusters => ["music", "books"])

    feed_and_wait_for_docs("books", 15, :file => selfdir + "books.15.xml", :cluster => "books")
    wait_for_hitcount("query=sddocname:books&search=books", 15)

    puts "Query: Match the 15 new docs in books"
    assert_result("query=sddocname:books&search=books&hits=99",
                  selfdir + "indexaddressing.3b.result.json",
                  "author",
                  [ "title", "author", "artist", "mid" ])
    puts "Query: Match the 10 new docs in music"
    assert_result("query=sddocname:music&search=music",
                  selfdir + "indexaddressing.2b.result.json",
                  "artist",
                  [ "author", "artist", "mid" ])
    puts "Query: Blend matches from both"
    assert_result("query=modern",
                  selfdir + "indexaddressing.5.result.json",
                  "title",
                  [ "title", "author", "artist", "mid" ])

  end

  def teardown
    stop
  end

end
