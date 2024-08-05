# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class HighlightTermsGram < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    set_description("Test that it is possible to supply extra highlight terms/phrases for juniper for gram indexes")
  end

  def test_highlightterms_ngram
    deploy_app(SearchApp.new.sd(selfdir+"ngram_sd/doc.sd"))
    start
    feed_and_wait_for_docs("doc", 1, :file => selfdir + "ngram_docs.json")
    assert_result("yql=select+*+from+doc+where+content+contains+%22doc%22%3B&format=json", selfdir + "ngram.0.result.json", "documentid", ["content"])
  end

  def teardown
    stop
  end

end
