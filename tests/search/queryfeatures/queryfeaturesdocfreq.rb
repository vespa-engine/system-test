# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class QueryFeaturesDocFreq < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
  end

  #---------- term with docfreq----------#
  def test_term_with_docfreq
    set_description("Test for the term.significance feature using backend document frequency")
    deploy_app(SearchApp.new.sd(selfdir+"docfreq.sd"))
    start
    feed_and_wait_for_docs("docfreq", 10, :file => selfdir + "docfreq.xml")

    last = assert_greater_significance(0.0,  "a")
    last = assert_greater_significance(last, "b")
    last = assert_greater_significance(last, "c")
    last = assert_greater_significance(last, "d")
    last = assert_greater_significance(last, "e")
    last = assert_greater_significance(last, "f")
    last = assert_greater_significance(last, "g")
    last = assert_greater_significance(last, "h")
    last = assert_greater_significance(last, "i")
    last = assert_greater_significance(last, "j")

    # phrase search: normalized doc freq = lowest / (2)^(num terms - 1)
    last = assert_greater_significance(0.0,  "\"a b\"")
           assert_greater_significance(last, "\"a b c\"")
    last = assert_greater_significance(0.0,  "\"f g\"")
           assert_greater_significance(last, "\"f g h\"")
  end

  def assert_greater_significance(exp, query)
    query = "query=" + query
    sf = search(query).hit[0].field["summaryfeatures"]
    act = sf.fetch("term(0).significance")
    puts "assert_greater_significance: #{act} > #{exp}"
    assert(act > exp)
    return act
  end

  def teardown
    stop
  end

end
