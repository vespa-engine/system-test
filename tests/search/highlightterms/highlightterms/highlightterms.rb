# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class HighlightTerms < IndexedSearchTest

  def setup
    set_owner("geirst")
    set_description("Test that it is possible to supply extra highlight terms/phrases for juniper")
  end

  def test_highlightterms
    add_bundle(selfdir + "HighlightSearcher.java");
    deploy_app(SearchApp.new.sd(selfdir+"sd1/music.sd").
               search_chain(SearchChain.new.
                            add(Searcher.new("com.yahoo.prelude.systemtest.HighlightSearcher",
                                             "rawQuery", "transformedQuery"))))
    start
    feed_and_wait_for_docs("music", 4, :file => selfdir+"music.10.xml", :timeout => 240)
    assert_result("query=sddocname:music",
                   selfdir + "music.result.xml",
                   "jtitle", ["jtitle", "jcategories"])
  end

  def test_highlightterms_logical
    add_bundle(selfdir + "HighlightSearcher.java");
    deploy_app(SearchApp.new.sd(selfdir+"sd2/music.sd").sd(selfdir+"sd2/books.sd").
               search_chain(SearchChain.new.
                            add(Searcher.new("com.yahoo.prelude.systemtest.HighlightSearcher",
                                             "rawQuery", "transformedQuery"))))
    start
    feed_and_wait_for_docs("music", 4, :file => selfdir + "musicbooks.10.xml")
    assert_result("query=blues", selfdir + "musicbooks.result.xml", "title", ["title", "categories"])
  end

  def teardown
    stop
  end

end
