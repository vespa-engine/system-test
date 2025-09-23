# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class AttributePrefetch < IndexedOnlySearchTest

  def setup
    set_owner("havardpe")
    add_bundle(selfdir+"AttributePrefetchTestSearcher.java")
    search_chain = Chain.new("default", "vespa").
        add(Searcher.new("com.yahoo.vespatest.attributeprefetch.AttributePrefetchTestSearcher", "transformedQuery", "blendedResult"))
    deploy_app(SearchApp.new.sd(selfdir+"attr.sd").container(
                 Container.new.
                   search(Searching.new.chain(search_chain)).
                   documentapi(ContainerDocumentApi.new)))
    start
  end

  def test_attributeprefetch
    feed_and_wait_for_docs("attr", 1, :file => selfdir+"attr.json")
    3.times do
      result = search("/?query=x")
      assert (result.xmldata.include? "TEST SEARCHER: OK")
      assert !(result.xmldata.include? "TEST SEARCHER: ERROR: 'body' should be set after filling in docsums")

    end
    3.times do
      result = search("/?query=x&summary=attributeprefetch")
      assert !(result.xmldata.include? "TEST SEARCHER: OK")
      assert (result.xmldata.include? "TEST SEARCHER: ERROR: 'body' should be set after filling in docsums")
    end
    3.times do
      assert_result("/?query=x&notestsearcher", selfdir+"qx1.result.json")
      assert_result("/?query=x&notestsearcher&summary=attributeprefetch",
                     selfdir+"qx2.result.json", nil, ["stringfield", "floatfield", "doublefield", "int64field", "bytefield1", "bytefield2", "intfield"])
    end
    assert_result("/?query=x&notestsearcher&nocache", selfdir+"qx1.result.json")
    assert_result("/?query=x&notestsearcher&summary=attributeprefetch&nocache",
                   selfdir+"qx2.result.json", nil, ["stringfield", "floatfield", "doublefield", "int64field", "bytefield1", "bytefield2", "intfield"])
  end


end
