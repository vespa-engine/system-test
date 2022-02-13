# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SimpleSearcherDeploymentWithIndex < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests the application package produced in section 2 of search-container.html, but with an index in addition")
  end

  def test_simple_searcher_deployment_with_index
    add_bundle(selfdir+"SimpleSearcher.java")
    deploy_app(SearchApp.new.sd(selfdir + "music.sd").
                        search_chain(SearchChain.new.add(Searcher.new(
                            "com.yahoo.search.example.SimpleSearcher"))))
    start
    feed_and_wait_for_docs("music", 10, :file => SEARCH_DATA + "music.10.xml")

    assert_result("query=classic", selfdir+"hello_world_result.json")
  end

  def teardown
    stop
  end

end
