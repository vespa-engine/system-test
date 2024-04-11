# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class RestrictParameter < IndexedOnlySearchTest

  def setup
    set_owner("arnej")
    set_description("Check restrict parameter in search requests is used properly")
    deploy_app(SearchApp.new.sd(selfdir+"basic.sd").
                      sd(selfdir+"notbasic.sd").cluster_name("logical"))
    start
  end

  def test_restrictparameter
    feed_and_wait_for_docs("notbasic", 1, :file => selfdir+"restrictparameter.2.json", :cluster => "logical")

    query = "/?query=bothtypes:type"
    puts "Controlling recall for both document types"
    tree = search(query).json
    puts "Total hitcount is %d" % tree["root"]["fields"]["totalCount"]
    puts "Tree = " + tree["root"].to_s
    assert_equal(2, tree["root"]["fields"]["totalCount"])

    query = "/?query=uniq:recall&search=logical&restrict=notbasic&tracelevel=1"
    tree = search(query).json
    puts "Total hitcount is %d" % tree["root"]["fields"]["totalCount"]
    assert_equal(1, tree["root"]["fields"]["totalCount"])
    # The trace message we are looking for is something like: sc0.num1 search to dispatch: query=[...
    parsed = tree["trace"]["children"][1]["children"][0]["children"][0]["message"]
    puts "Checking the existance of the search term 'recall' with explicit index"
    puts "Search term was: %s" % parsed[/[a-z0-9_]*:recall/]
    assert parsed[/[a-z0-9_]*:recall/] != nil

    query = "/?query=uniq:recall&search=logical&restrict=basic&tracelevel=1"
    tree = search(query).json
    puts "Total hitcount is %d" % tree["root"]["fields"]["totalCount"]
    assert_equal(0, tree["root"]["fields"]["totalCount"])
    # The trace message we are looking for is something like: sc0.num1 search to dispatch: query=[...
    parsed = tree["trace"]["children"][1]["children"][0]["children"][0]["message"]
    puts "Searching for the 'AND uniq recall'" + parsed
    puts "Search phrase was: %s" % parsed[/AND uniq recall/]
    assert parsed[/uniq recall/] != nil
  end

  def teardown
    stop
  end

end

