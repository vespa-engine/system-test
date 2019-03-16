# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bolding < IndexedSearchTest

  def check_result(q, fn)
    fnam = selfdir+@subdir+"/"+fn+".result"
    puts "checking #{fnam}"
    # save_result("query=#{q}", fnam)
    assert_result("query=#{q}", fnam)
  end

  def setup
    set_owner("arnej")
  end

  def test_bolding
    do_test("stemming-none")
  end

  def test_bolding_stemming
    do_test("stemming-shortest")
  end

  def test_bolding_multiplestems
    do_test("stemming-multiple")
  end

  def do_test(subdir)
    @subdir = subdir
    deploy_app(SearchApp.new.sd(selfdir+subdir + "/bolding.sd"))
    start

    puts "Description: Bolding of words from query in displayed summary"
    puts "Component: Config, Indexing, Search etc"
    puts "Feature: Bolding"

    feed_and_wait_for_docs("bolding", 10, :file => selfdir + "input.xml")

    puts "Query: sanity checks"
    assert_hitcount("query=sddocname:bolding", 10)
    assert_hitcount("query=electric", 2)

    puts "Query: bolding checks"
    check_result("chicago",                              "chicago")
    check_result("title:chicago",                        "chicago")
    check_result("song:chicago",                         "chicago")
    check_result("chicago&bolding=false",                "chicagonb")
    check_result("electric",                             "bolding")
    check_result("electric",                             "bolding")
    check_result("sddocname:bolding&filter=%2Belectric", "notrybolding")
    check_result("electric",                             "bolding")
    check_result("electric&bolding",                     "bolding")
    check_result("electric&bolding=true",                "bolding")
    check_result("electric&bolding=false",               "nobolding")

    puts "Query: bolding with summary-to checks"
    check_result("chicago&summary=small",                "csmall")
    check_result("chicago&summary=large",                "clarge")
    check_result("electric&summary=small",               "esmall")
    check_result("electric&summary=large",               "elarge")

    puts "Query: bolding of stemmed words"
    check_result("title:numb",                           "numb")
    check_result("title:number",                         "number")
    check_result("title:numbers",                        "numbers")
    check_result("title:numbing",                        "numbing")

    check_result("title:blue",                           "blue")
    check_result("title:Blue",                           "blue")
    check_result("title:blues",                          "blues")
    check_result("title:Blues",                          "blues")
    check_result("title:BLUES",                          "blues")
  end

  def test_bolding_in_addition_to_advanced_search_operators
    set_owner("geirst")
    set_description("Test the combination of bolding in addition to advanced search operators in the query")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed(:file => selfdir + "doc.json", :json => true)
    exp_title_field = "Best of <hi>Metallica</hi>"
    assert_field_value("?query=select+*+from+sources+*+where+title+contains+'Metallica'%3B&type=yql", "title", exp_title_field)
    assert_field_value("?query=select+*+from+sources+*+where+title+contains+'Metallica' and weightedSet(year,{'2001':1})%3B&type=yql", "title", exp_title_field)
    assert_field_value("?query=select+*+from+sources+*+where+title+contains+'Metallica'and+artist+matches+'metallica'%3B&type=yql", "title", exp_title_field)
  end

  def teardown
    stop
  end

end
