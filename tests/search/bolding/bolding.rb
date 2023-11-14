# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Bolding < IndexedSearchTest

  def check_result(q, fn)
    fnam = selfdir+@subdir+"/"+fn+".result.json"
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

  def do_test(testname)
    @subdir = testname
    deploy_app(SearchApp.new.sd(selfdir+testname+"/bolding.sd"))
    start

    puts "Description: Bolding of words from query in displayed summary"
    puts "Component: Config, Indexing, Search etc"
    puts "Feature: Bolding"

    feed_and_wait_for_docs("bolding", 10, :file => selfdir + "input.xml")

    puts "Query: sanity check"
    assert_hitcount("query=sddocname:bolding", 10)

    puts "Query: bolding checks"
    check_result("chicago",                               "chicago")
    check_result("title:chicago",                         "title-chicago")
    check_result("song:chicago",                          "song-chicago")
    check_result("chicago&bolding=false",                 "chicagonb")
    check_result("electrics",                             "bolding")
    check_result("electric",                              "bolding")      if testname != "stemming-none"
    check_result("sddocname:bolding&filter=%2Belectrics", "notrybolding")
    check_result("sddocname:bolding&filter=%2Belectric",  "notrybolding") if testname != "stemming-none"
    check_result("electrics&bolding",                     "bolding")
    check_result("electric&bolding",                      "bolding")      if testname != "stemming-none"
    check_result("electrics&bolding=true",                "bolding")
    check_result("electric&bolding=true",                 "bolding")      if testname != "stemming-none"
    check_result("electrics&bolding=false",               "nobolding")
    check_result("electric&bolding=false",                "nobolding")    if testname != "stemming-none"

    puts "Query: bolding with summary-to checks"
    check_result("chicago&summary=small",                "csmall")
    check_result("chicago&summary=large",                "clarge")
    check_result("electrics&summary=small",              "esmall")
    check_result("electric&summary=small",               "esmall")       if testname != "stemming-none"
    check_result("electrics&summary=large",              "elarge")
    check_result("electric&summary=large",               "elarge")       if testname != "stemming-none"
  end

  def test_bolding_in_addition_to_advanced_search_operators
    set_owner("geirst")
    set_description("Test the combination of bolding in addition to advanced search operators in the query")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed(:file => selfdir + "doc.json")
    exp_title_field = "Best of <hi>Metallica</hi>"

    result = search("?query=select+*+from+sources+*+where+title+contains+'Metallica'%3B&type=yql")
    assert_equal(exp_title_field, result.hit[0].field['title'])
    result = search("?query=select+*+from+sources+*+where+title+contains+'Metallica' and weightedSet(year,{'2001':1})%3B&type=yql")
    assert_equal(exp_title_field, result.hit[0].field['title'])
    result = search("?query=select+*+from+sources+*+where+title+contains+'Metallica'and+artist+matches+'metallica'%3B&type=yql")
    assert_equal(exp_title_field, result.hit[0].field['title'])
  end

  def teardown
    stop
  end

end
