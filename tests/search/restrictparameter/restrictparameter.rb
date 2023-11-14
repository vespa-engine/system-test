# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class RestrictParameter < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Check restrict parameter in search requests is used properly")
    deploy_app(SearchApp.new.sd(selfdir+"basic.sd").
                      sd(selfdir+"notbasic.sd").cluster_name("logical"))
    start
  end

  def test_restrictparameter
    feed_and_wait_for_docs("notbasic", 1, :file => SEARCH_DATA+"restrictparameter.2.xml", :cluster => "logical")

    query = "/?query=bothtypes:type&format=json"
    puts "Controlling recall for both document types"
    tree = search(query).json
    puts "Total hitcount is %d" % tree["root"]["fields"]["totalCount"]
    assert_equal(2, tree["root"]["fields"]["totalCount"])

    query = "/?query=uniq:recall&search=logical&restrict=notbasic&tracelevel=1&format=json"
    tree = search(query).json
    puts "Total hitcount is %d" % tree["root"]["fields"]["totalCount"]
    assert_equal(1, tree["root"]["fields"]["totalCount"])
    # The trace message we are looking for is something like: sc0.num1 search to dispatch: query=[...
    parsed = tree["trace"]["children"][1]["children"][0]["children"][0]["message"]
    puts "Checking the existance of the search term 'recall' with explicit index"
    puts "Search term was: %s" % parsed[/[a-z0-9_]*:recall/]
    assert parsed[/[a-z0-9_]*:recall/] != nil

    query = "/?query=uniq:recall&search=logical&restrict=basic&tracelevel=1&format=json"
    tree = search(query).json
    puts "Total hitcount is %d" % tree["root"]["fields"]["totalCount"]
    assert_equal(0, tree["root"]["fields"]["totalCount"])
    # The trace message we are looking for is something like: sc0.num1 search to dispatch: query=[...
    parsed = tree["trace"]["children"][1]["children"][0]["children"][0]["message"]
    puts "Searching for the phrase \"uniq recall\""
    puts "Search phrase was: %s" % parsed[/"uniq recall"/]
    assert parsed[/\"uniq recall\"/] != nil
  end

  def teardown
    stop
  end

end

