# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class HighlightTerms < IndexedStreamingSearchTest

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
    vespa.adminserver.logctl("searchnode:visitor.instance.searchvisitor", "debug=on")
    feed_and_wait_for_docs("music", 4, :file => selfdir+"music.10.json", :timeout => 240)
    assert_result("query=sddocname:music",
                   selfdir + "music.result.json",
                   "jtitle", ["jtitle", "jcategories"])
  end

  def test_highlightterms_logical
    add_bundle(selfdir + "HighlightSearcher.java");
    deploy_app(SearchApp.new.sd(selfdir+"sd2/music.sd").sd(selfdir+"sd2/books.sd").
               search_chain(SearchChain.new.
                            add(Searcher.new("com.yahoo.prelude.systemtest.HighlightSearcher",
                                             "rawQuery", "transformedQuery"))))
    start
    feed_and_wait_for_docs("music", 4, :file => selfdir + "musicbooks.10.json")
    assert_result("query=blues", selfdir + "musicbooks.result.json", "title", ["title", "categories"])
  end

  def teardown
    stop
  end

end
