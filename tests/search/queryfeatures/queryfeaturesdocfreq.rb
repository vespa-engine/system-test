# coding: utf-8
# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class QueryFeaturesDocFreq < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  #---------- term with docfreq----------#
  def test_term_with_docfreq
    set_description("Test for the term.significance feature using backend document frequency")
    deploy_app(SearchApp.new.sd(selfdir+"docfreq.sd"))
    start
    feed_and_wait_for_docs("docfreq", 10, :file => selfdir + "docfreq.json")
    run_test_term_with_docfreq_from_backend unless is_streaming
    run_test_term_with_significance_from_query
    run_test_term_with_docfreq_from_query
  end

  def run_test_term_with_docfreq_from_backend
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

  def get_significance(annotation)
    yql = "select * from sources * where default contains ({#{annotation}}\"a\")"
    sf = search({'yql' => yql}).hit[0].field["summaryfeatures"]
    sf.fetch("term(0).significance")
  end

  def get_df_significance(frequency, count)
    get_significance("documentFrequency: { frequency: #{frequency}, count: #{count}}")
  end

  def run_test_term_with_significance_from_query
    assert_approx(0.1, get_significance('significance: 0.1'))
    assert_approx(0.5, get_significance('significance: 0.5'))
    assert_approx(1.0, get_significance('significance: 1.0'))
  end

  def run_test_term_with_docfreq_from_query
    eps = 1e-7
    assert_approx(1.0, get_df_significance(1, 1000000), eps)
    assert_approx(0.5, get_df_significance(1000000, 1000000), eps)
    sig_10_of_100 = get_df_significance(10, 100)
    sig_8_of_100 = get_df_significance(8, 100)
    sig_10_of_110 = get_df_significance(10, 110)
    assert(sig_10_of_100 < sig_8_of_100, "sig_10_of_100 < sig_8_of_100 failed")
    assert(sig_10_of_100 < sig_10_of_110, "sig_10_of_100 < sig_10_of_110 failed")
    # Scaling frequency and count doesn't change legacy significance
    assert_approx(sig_10_of_100, get_df_significance(100, 1000), eps)
    assert_approx(sig_8_of_100, get_df_significance(80, 1000), eps)
  end

  def teardown
    stop
  end

end
