# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class QueryTypes < IndexedSearchTest

  def nightly?
    true
  end

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
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def compare(query, file)
    puts "checking if query #{query} matches saved result #{file}"
    assert_field("query="+query+"&hits=200", selfdir+file, "surl", true)
    assert_field("query="+query+"&hits=200", selfdir+file, "title", true)
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

    compare('do%20or%20not'         , "typeall.result")
    compare('do%20or%20not&type=all', "typeall.result")
    compare('(do%20or%20not)'       , "typeany.result")
    compare('do%20or%20not&type=any', "typeany.result")
    compare('"or%20not"'            , "typephrase.result")
    compare('or%20not&type=phrase'  , "typephrase.result")
    compare('(do%20not)'            , "typeadv.result")
    compare('do%20or%20not&type=adv', "typeadv.result")
    compare('do%20OR%20not&type=web', "typeadv.result")
    compare('do%20or%20not&type=web', "typeall.result")

    # Test - operator
    # Test + operator
    # Test quote operator
    # Test without quotes
    # Test (a or b)

    compare("frank+-zappa"          , "frank_minus_zappa.result")
    compare("%2Bthe+%2Bgift"        , "the_gift_plus.result")
    compare('"the+gift"'            , "the_gift_quoted.result")
    compare("the+gift"              , "the_gift_plus.result")
    compare("(zappa+broadway)"      , "zappa_or_broadway.result")

    # Advanced query incorporating 'AND', 'OR' and '(parenthesis)'
    # Advanced query incorporating 'OR' and 'ANDNOT'
    # same query as above, simple query syntax
    # Advanced query with just one word
    # Advanced query incorporating 'RANK', check for same results
    # Advanced query incorporating 'RANK', check that RANK has effect
    # Advanced query with 'AND', should have same results as previous
    # Advanced query incorporating 'RANK', check that RANK has effect
    # Advanced query with 'AND', should have same results as previous

    compare("%2B(young+and+best)+or+title:michael&type=adv", "adv1.result")
    compare("merchant+or+rank+or+bird+andnot+bird&type=adv", "adv2.result")
    compare("(wildflowers+rank+bird)+-bird"                , "adv2.result")
    compare("young&type=adv"                               , "adv3.result")
    compare("young+RANK+old&type=adv"                      , "adv3.result")
    assert_field("query=young+RANK+old&type=adv&hits=2"    , selfdir+"adv4.result", "title", true)
    compare("young+AND+old&type=adv"                       , "adv4b.result")
    assert_field("query=young+RANK+guns&type=adv&hits=1"   , selfdir+"adv5.result", "title")
    compare("young+AND+guns&type=adv"                      , "adv5b.result")
  end

  def teardown
    stop
  end

end
