# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class AttributePrefetchLogicalIndexes < IndexedSearchTest

  def setup
    set_owner("bratseth")
    add_bundle(selfdir+"TestSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.vespatest.attributeprefetch.TestSearcher", "transformedQuery", "blendedResult"))
    deploy_app(SearchApp.new.sd(selfdir+"attribute1.sd").sd(selfdir+"attribute2.sd").search_chain(search_chain))
    start
  end

  def test_attributeprefetch_logicalindexes
    puts "Description: Tests attribute prefetching with logical indexes"
    puts "Component: Searchdefinition, Qrs"
    puts "Feature: Logical indexes and attribute prefetching"

    feed_and_wait_for_docs("attribute2", 2, :file => selfdir + "feed.xml")

    3.times do
      result = search("x")
      assert (result.xmldata.include? "TEST SEARCHER: OK")
      assert !(result.xmldata.include? "TEST SEARCHER: ERROR")
    end
    3.times do
      result = search("x&summary=attributeprefetch")
      assert !(result.xmldata.include? "TEST SEARCHER: OK")
      assert (result.xmldata.include? "TEST SEARCHER: ERROR")
      assert (result.xmldata.include? "ERROR DETAILS: 'body' should be set after filling in docsums")
    end
   end

  def teardown
    stop
  end

end
