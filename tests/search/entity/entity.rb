# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Entity < IndexedSearchTest
  # Description: Test entity encoding.
  #              Data passed in should appear without modification after xml
  #              parsing of the result.
  # Component: Indexing and Searching
  # Feature: Entity encoding

  def setup
    set_owner("bratseth")
    deploy_app(SearchApp.new.sd(selfdir + "entity.sd"))
    start
  end

  def test_entity
    feed_and_wait_for_docs("entity", 3, :file => selfdir + "entity.3.xml", :encoding => "iso-8859-1")
    query = "query=content:test"
    wait_for_hitcount(query, 3)
    assert_result(query, selfdir + "entity.1.result.json", "id")
  end

  def teardown
    stop
  end

end
