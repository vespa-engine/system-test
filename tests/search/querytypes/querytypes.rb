# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class QueryTypes < IndexedSearchTest

  def timeout_seconds
    return  1800
  end

  def setup
    # TODO: This test blindly checks result sets. It needs to be rewritten from scratch.
    # Also, the rank algorithm here makes some of the queries very bad
    # bad test queries, as rank terms hardly have any effect at all
    # on rank score. This check mainly checks the recall effect of
    # the operator.
    # TODO: Write a fitting rank function for QueryTypes test
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
  end

  def compare(query, file)
    puts "checking if query #{query} matches saved result #{file}"
    assert_field("query="+query+"&hits=200", selfdir+file, "surl", true, 10)
    assert_field("query="+query+"&hits=200", selfdir+file, "title", true, 10)
  end

  def test_querytypes
    feed_and_wait_for_docs("music", 777, :file => SEARCH_DATA+"music.777.xml")

    # Search for terms 'do or not',   not using explicit type
    # Search for terms 'do or not',   using type 'all'
    # Search for terms '(do or not)', not using explicit type
    # Search for terms 'do or not',   using type 'any'
    # Search for terms '"or not"',    not using explicit type
    # Search for terms 'or not',      using type 'phrase'
    # Search for terms '(do not)',    not using explicit type
    # Search for terms 'do or not',   using type 'adv'

    compare('do%20or%20not'         , "typeall.result.json")
    compare('do%20or%20not&type=all', "typeall.result.json")
    compare('(do%20or%20not)'       , "typeany.result.json")
    compare('do%20or%20not&type=any', "typeany.result.json")
    compare('"or%20not"'            , "typephrase.result.json")
    compare('or%20not&type=phrase'  , "typephrase.result.json")
    compare('(do%20not)'            , "typeadv.result.json")
    compare('do%20or%20not&type=adv', "typeadv.result.json")
    compare('do%20OR%20not&type=web', "typeadv.result.json")
    compare('do%20or%20not&type=web', "typeall.result.json")

    # Test - operator
    # Test + operator
    # Test quote operator
    # Test without quotes
    # Test (a or b)

    compare("frank+-zappa"          , "frank_minus_zappa.result.json")
    compare("%2Bthe+%2Bgift"        , "the_gift_plus.result.json")
    compare('"the+gift"'            , "the_gift_quoted.result.json")
    compare("the+gift"              , "the_gift_plus.result.json")
    compare("(zappa+broadway)"      , "zappa_or_broadway.result.json")

    # Advanced query incorporating 'AND', 'OR' and '(parenthesis)'
    # Advanced query incorporating 'OR' and 'ANDNOT'
    # same query as above, simple query syntax
    # Advanced query with just one word
    # Advanced query incorporating 'RANK', check for same results
    # Advanced query incorporating 'RANK', check that RANK has effect
    # Advanced query with 'AND', should have same results as previous
    # Advanced query incorporating 'RANK', check that RANK has effect
    # Advanced query with 'AND', should have same results as previous

    compare("%2B(young+and+best)+or+title:michael&type=adv", "adv1.result.json")
    compare("merchant+or+rank+or+bird+andnot+bird&type=adv", "adv2.result.json")
    compare("(wildflowers+rank+bird)+-bird"                , "adv2.result.json")
    compare("young&type=adv"                               , "adv3.result.json")
    compare("young+RANK+old&type=adv"                      , "adv3.result.json")
    assert_field('query=young+RANK+old&type=adv&hits=2&type=all'    , selfdir+"adv4.result.json", "title", true)
    compare("young+AND+old&type=adv"                       , "adv4b.result.json")
    assert_field('query=young+RANK+guns&type=adv&hits=1&type=all'   , selfdir+"adv5.result.json", "title")
  end

  def teardown
    stop
  end

end
