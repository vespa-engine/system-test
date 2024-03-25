# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'app_generator/http'

class SearchchainsClusterConnections < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Tests that chains are using the correct local provider, no matter what order the clusters are defined")
  end
  
  def deploy(doctype1, doctype2)
    deploy_app(SearchApp.new.
               enable_document_api.
               cluster(SearchCluster.new(doctype1).sd(selfdir + "#{doctype1}.sd").
                       doc_type(doctype1)).
               cluster(SearchCluster.new(doctype2).sd(selfdir + "#{doctype2}.sd").
                       doc_type(doctype2)).
               container(Container.new("container1").
                         search(Searching.new.chain(Provider.new(doctype1, "local").cluster(doctype1)))).
               container(Container.new("container2").http(Http.new.server(Server.new("default", "5000"))).
                         search(Searching.new.chain(Provider.new(doctype2, "local").cluster(doctype2)))))
  end

  def test_music_first_then_books
    deploy("music", "books")
    start_and_feed
    check_hits_from_each_cluster
  end

  def test_books_first_then_music
    deploy("books", "music")
    start_and_feed
    check_hits_from_each_cluster
  end

  def start_and_feed
    start
    feed_and_wait_for_docs("music", 10, {:file => SEARCH_DATA+"music.10.xml"}, "", {:cluster => "container1"})
    feed_and_wait_for_docs("books", 5, {:file => selfdir + "books.1.xml", :clusters => [ "books"]}, "", {:cluster => "container2"})
   end

  def check_hits_from_each_cluster
    assert_hits("music", "Classic Female Blues", 1, "container1") # hit with first qrserver/container (music provider)
    assert_hits("books", "Classic Female Blues", 0, "container2") # no hits with second qrserver/container (books provider)

    assert_hits("music", "The Complete Civil War Letters", 0, "container1") # no hits with first qrserver/container  (music provider)
    assert_hits("books", "The Complete Civil War Letters", 1, "container2") # hit with second qrserver/container (books provider)
  end

  def assert_hits(doctype, query, hits, container_cluster)
    assert_hitcount("query=#{query}&searchChain=#{doctype}&type=all", hits, 0, { :cluster => container_cluster })
  end

  def teardown
    stop
  end
  
end
