# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class RoutingTest < IndexedStreamingSearchTest

  def setup
    set_owner("vekterli")
    @get_params = {}
  end

  def three_cluster_app
    SearchApp.new.
           cluster(
             SearchCluster.new("music").sd(selfdir + "music.sd").
             doc_type("music", "music.year > 0")).
           cluster(
             SearchCluster.new("books").sd(selfdir + "book.sd").
             doc_type("book", "book.year > 0")).
           storage(StorageCluster.new.default_group.
                   doc_type("music").
                   doc_type("book"))
  end

  def two_cluster_app
    SearchApp.new.
           cluster(
             SearchCluster.new("music").sd(selfdir + "music.sd").
             doc_type("music", "music.year / 3 > 0")).
           cluster(
             SearchCluster.new("books").sd(selfdir + "book.sd").
             doc_type("book", "book.year / 3 > 0"))
  end

  def test_multicluster_with_selection_get
    deploy_app(two_cluster_app)
    start
    feed_and_wait_for_docs("music", 1, :file => selfdir + "bookandmusic_feed.json", :trace => 9)
    vespa.document_api_v1.put(getIronMaiden)
    wait_for_hitcount("sddocname:music", 2)
    assert_result("search=music&query=metallica", selfdir + "metallica_result.json")
    assert_result("search=music&query=prince", selfdir + "lepetitprince_result.json")
    assert_equal(getMetallica(), vespa.document_api_v1.get("id:music:music::http://music.yahoo.com/metallica/BestOf", @get_params))
    assert_equal(getLePetitPrince(), vespa.document_api_v1.get("id:book:book::lepetitprince", @get_params))
  end

  def test_feedToSearchAndStorage
    deploy_app(three_cluster_app)
    start
    # Feed to search
    feed_and_wait_for_docs("music", 1, :file => selfdir + "bobdylan_feed.json", :route => "indexing", :trace => 9)
    assert_result("search=music&query=bob", selfdir + "bobdylan_result.json")

    # Feed to storage
    feed(:file => selfdir + "bobdylan_feed.json", :route => "storage", :trace => 9)
    assert_equal(getBobDylan(), vespa.document_api_v1.get("id:music:music::http://music.yahoo.com/bobdylan/BestOf", @get_params))

    # Feed to both search and storage. When sending to search AND storage, at least one recipient accepts them.
    feed_and_wait_for_docs("music", 2, :file => selfdir + "metallica_feed.json", :route => "\"[AND:indexing storage]\"", :trace => 9)
    assert_result("search=music&query=metallica", selfdir + "metallica_result.json")
    assert_equal(getMetallica(), vespa.document_api_v1.get("id:music:music::http://music.yahoo.com/metallica/BestOf", @get_params))
  end

  def test_musicClusterIgnoresBooks
    deploy_app(three_cluster_app)
    start
    feed_and_wait_for_docs("music", 1, :file => selfdir + "bookandmusic_feed.json", :route => "\"[AND:indexing storage]\"", :trace => 9)
    vespa.document_api_v1.put(getIronMaiden)
    wait_for_hitcount("sddocname:music", 2)
    assert_result("search=music&query=metallica", selfdir + "metallica_result.json")
    assert_result("search=music&query=prince", selfdir + "lepetitprince_result.json")
    assert_equal(getMetallica(), vespa.document_api_v1.get("id:music:music::http://music.yahoo.com/metallica/BestOf", @get_params))
    assert_equal(getLePetitPrince(), vespa.document_api_v1.get("id:book:book::lepetitprince", @get_params))
  end

  def getLePetitPrince
    doc = Document.new("book", "id:book:book::lepetitprince").
      add_field("title", "Le Petit Prince").
      add_field("author", "Antoine de Saint-Exupery").
      add_field("year", 1943)
    return doc
  end

  def getBobDylan
    doc = Document.new("music",
      "id:music:music::http://music.yahoo.com/bobdylan/BestOf").
      add_field("title", "Best of Bob Dylan").
      add_field("artist", "Bob Dylan").
      add_field("year", 1008)
    return doc
  end

  def getMetallica
    doc = Document.new("music",
       "id:music:music::http://music.yahoo.com/metallica/BestOf").
      add_field("title", "Best of Metallica").
      add_field("artist", "Metallica").
      add_field("year", 1977)
    return doc
  end

  def getIronMaiden
    Document.new("music", "id:music:music::http://music.yahoo.com/maiden/BestOf").
      add_field("title", "Best of Iron Maiden").
      add_field("artist", "Iron Maiden").
      add_field("year", 1981)
  end

  def teardown
    stop
  end

end
