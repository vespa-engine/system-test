# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class QueryFeatures < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  #---------- query ----------#
  def test_query
    set_description("Test the query feature")
    deploy_app(SearchApp.new.sd(selfdir+"query.sd"))
    start
    feed_and_wait_for_docs("query", 1, :file => selfdir + "query.xml", :name => "query")

    assert_query({"query(foo)" => 5.5},  "")
    assert_query({"query(foo)" => 10.5}, "&rankproperty.foo=10.5")
    assert_query({"query(foo)" => 10.5}, "&rankfeature.query(foo)=10.5")

    assert_query({"query(foo.bar)" => 0},    "")
    assert_query({"query(foo.bar)" => 30.5}, "&rankproperty.foo.bar=30.5")
    assert_query({"query(foo.bar)" => 30.5}, "&rankfeature.query(foo.bar)=30.5")

    assert_query({"query(foo.bar.baz)" => 0},    "")
    assert_query({"query(foo.bar.baz)" => 40.5}, "&rankproperty.foo.bar.baz=40.5")

    assert_query({"query(foo)" => 10.5, "query(foo.bar)" => 20.5}, "&rankproperty.foo=10.5&rankproperty.foo.bar=20.5")

    assert_query({"rankingExpression(mysum)" => 6},  "&ranking=vector")
    assert_query({"rankingExpression(mysum)" => 12}, "&ranking=vector&ranking.features.query(bar)=[2,4,6]")
  end

  def assert_query(expected, rankproperties)
    query = "query=a" + rankproperties
    result = search(query)
    sf = result.hit[0].field["summaryfeatures"]
    assert_features(expected, sf)
  end


  #---------- queryTermCount ----------#
  def test_query_term_count
    set_description("Test the queryTermCount feature")
    deploy_app(SearchApp.new.sd(selfdir+"querytermcount.sd"))
    start
    feed_and_wait_for_docs("querytermcount", 1, :file => selfdir + "querytermcount.xml")

    assert_query_term_count(1, "a:a")
    assert_query_term_count(1, "b:b")
    assert_query_term_count(2, "a:a+a:a")
    assert_query_term_count(2, "a:a+b:b")
    assert_query_term_count(3, "a:a+b:b+b:x&type=any")
  end

  def assert_query_term_count(exp, query)
    query = "query=" + query
    assert_features({"queryTermCount" => exp}, search(query).hit[0].field['summaryfeatures'])
  end


  #---------- term ----------#
  def test_term
    set_description("Test the term feature")
    add_bundle(selfdir + "ConnexitySearcher.java")
    add_bundle(selfdir + "SignificanceSearcher.java")
    add_bundle(selfdir + "ReverseSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.queryfeatures.ConnexitySearcher", "unblendedResult", "significance").provides("connexity")).
      add(Searcher.new("com.yahoo.queryfeatures.SignificanceSearcher", "connexity", "reverse").provides("significance")).
      add(Searcher.new("com.yahoo.queryfeatures.ReverseSearcher", "significance", "backend").provides("reverse"))
    deploy_app(SearchApp.new.sd(selfdir+"term.sd").search_chain(search_chain))
    start
    feed_and_wait_for_docs("term", 1, :file => selfdir + "term.xml")

    # default significance (search::features::util::getSignificance(1.0))
    ds = (is_streaming ? 1.0 : 0.5)
    run_term_test(ds)

    if !is_streaming
      # change weight both index and attribute
      assert_term(0, ds, 200, 0.1, "a!200+b!300+d:d!400")
      assert_term(1, ds, 300, 0.1, "a!200+b!300+d:d!400")
      assert_term(2, ds, 400, 0.1, "a!200+b!300+d:d!400")
    end
  end

  def run_term_test(ds) # default significance
    # normalized backend document frequency:
    #  - terms: a, b, c: 1 -> significance ds
    #  - terms: d:       1 -> significance ds (attributes will also return estimated hit count, and a docfreq is calculated based on this)

    # default values when searching in an index
    assert_term(0, ds, 100, 0.1, "a")
    assert_term(1,  0,   0,   0, "a")
    assert_term(2,  0,   0,   0, "a")
    assert_term(0, ds, 100, 0.1, "a+b")
    assert_term(1, ds, 100, 0.1, "a+b")
    assert_term(2,  0,   0,   0, "a+b")
    assert_term(0, ds, 100, 0.1, "a+b+c")
    assert_term(1, ds, 100, 0.1, "a+b+c")
    assert_term(2, ds, 100, 0.1, "a+b+c")
    # both index and attribute
    assert_term(0, ds, 100, 0.1, "a+d:d")
    assert_term(1, ds, 100, 0.1, "a+d:d")
    assert_term(2,  0,   0,   0, "a+d:d")
    assert_term(0, ds, 100, 0.1, "d:d")
    assert_term(1,  0,   0,   0, "d:d")
    assert_term(2,  0,   0,   0, "d:d")


    # change weight
    assert_term(0, ds, 200, 0.1, "a!200+b!300+c!400")
    assert_term(1, ds, 300, 0.1, "a!200+b!300+c!400")
    assert_term(2, ds, 400, 0.1, "a!200+b!300+c!400")
    # reverse query term order
    assert_term(0, ds, 400, 0.1, "a!200+b!300+c!400&reverse")
    assert_term(1, ds, 300, 0.1, "a!200+b!300+c!400&reverse")
    assert_term(2, ds, 200, 0.1, "a!200+b!300+c!400&reverse")


    # change connectedness
    query = "a+b+c&connexity=b:a:0.2,c:b:0.3&nostemming"
    assert_term(0, ds, 100, 0.1, query)
    assert_term(1, ds, 100, 0.2, query)
    assert_term(2, ds, 100, 0.3, query)
    # both index and attribute
    query = "a+b+d:d&connexity=b:a:0.4,d:b:0.5&nostemming"
    assert_term(0, ds, 100, 0.1, query)
    assert_term(1, ds, 100, 0.4, query)
    assert_term(2, ds, 100, 0.5, query)


    # change significance
    query = "a+b+c&significance=a:0.2,b:0.3,c:0.4&nostemming"
    assert_term(0, 0.2, 100, 0.1, query)
    assert_term(1, 0.3, 100, 0.1, query)
    assert_term(2, 0.4, 100, 0.1, query)
    # both index and attribute
    query = "a+b+d:d&significance=a:0.5,b:0.6,d:0.7&nostemming"
    assert_term(0, 0.5, 100, 0.1, query)
    assert_term(1, 0.6, 100, 0.1, query)
    assert_term(2, 0.7, 100, 0.1, query)
  end

  def assert_term(termidx, significance, weight, connectedness, query)
    query = "query=" + query + "&parallel"
    result = search(query)
    sf = result.hit[0].field["summaryfeatures"]
    fn = "term(#{termidx})"
    assert_features({fn + ".significance" => significance, fn + ".weight" => weight, \
                     fn + ".connectedness" => connectedness}, sf)
  end

  def teardown
    stop
  end

end
