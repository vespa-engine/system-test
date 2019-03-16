# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Ar < IndexedSearchTest
  def setup
    set_owner("bratseth")
    set_description("Test of Arabic indexing")
    deploy_app(SearchApp.new.sd("#{selfdir}/arabic.sd"))
    start
  end

  def test_arabic_matching
    feed_and_wait_for_docs("arabic", 2, :file => "#{selfdir}/arabic.xml")

    # precomposed accented char
    assert_hitcount("query=%D8%A3%D8%A8%D8%AD%D8%AB&language=ar", 2)
    # combining sequence accented char
    assert_hitcount("query=%D8%A7%D9%94%D8%A8%D8%AD%D8%AB&language=ar", 2)
    # transformed away accent
    assert_hitcount("query=%D8%A7%D8%A8%D8%AD%D8%AB&language=ar", 2)

    ###
    ### NOT language=ar
    ###
    # precomposed accented char
    assert_hitcount("query=%D8%A3%D8%A8%D8%AD%D8%AB", 0)
    # combining sequence accented char
    assert_hitcount("query=%D8%A7%D9%94%D8%A8%D8%AD%D8%AB", 0)
    # transformed away accent
    assert_hitcount("query=%D8%A7%D8%A8%D8%AD%D8%AB", 0)
  end

  def test_arabic_literal_ranking
    feed_and_wait_for_docs("arabic", 2, :file => "#{selfdir}/arabic.xml")

    # precomposed accented char
    assert_result("query=%D8%A3%D8%A8%D8%AD%D8%AB&ranking=literal&language=ar",
                  "#{selfdir}/result_accent.xml")
    # combining sequence accented char
    assert_result("query=%D8%A7%D9%94%D8%A8%D8%AD%D8%AB&ranking=literal&language=ar",
                  "#{selfdir}/result_combaccent.xml")
    # transformed away accent
    assert_result("query=%D8%A7%D8%A8%D8%AD%D8%AB&ranking=literal&language=ar",
                  "#{selfdir}/result_noaccent.xml")
  end

  def teardown
    stop
  end

end
