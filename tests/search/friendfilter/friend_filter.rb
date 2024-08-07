# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class FriendFilter < IndexedOnlySearchTest

  def timeout_seconds
    return 1200
  end

  def setup
    set_owner("arnej")
    set_description("Demonstrate friend filter use case for weighted set term search")
  end

  def test_weighted_set_item_casing
    add_bundle(selfdir + "FriendFilterSearcher.java")
    deploy_app(SearchApp.new.
               config(
                     ConfigOverride.new("search.querytransform.lowercasing").
                     add("transform_weighted_sets", "false")).
               sd(selfdir+"friendslist.sd").
               sd(selfdir+"blogpost.sd").
               threads_per_search(1).
               search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.FriendFilterSearcher"))))

    start
    feed(:file => selfdir+"casings.json")
    wait_for_hitcount("sddocname:friendslist", 3)
    wait_for_hitcount("sddocname:blogpost", 12)

    assert_hitcount('query=title:foo&type=all', 6)
    assert_hitcount('query=title:bar&type=all', 6)

    assert_hitcount('query=author:null&type=all', 5)
    assert_hitcount('query=author:0&type=all', 7)

    assert_hitcount('query=title:foo+author:null&type=all', 2)
    assert_hitcount('query=title:bar+author:null&type=all', 3)

    assert_hitcount('query=title:foo&username=a1&type=all', 2)
    assert_hitcount('query=title:foo&username=b2&type=all', 2)
    assert_hitcount('query=title:foo&username=c3&type=all', 2)

    assert_hitcount('query=title:bar&username=a1&type=all', 3)
    assert_hitcount('query=title:bar&username=b2&type=all', 3)
    assert_hitcount('query=title:bar&username=c3&type=all', 3)

    assert_hitcount('query=sddocname:blogpost&username=a1&type=all', 5)
    assert_hitcount('query=sddocname:blogpost&username=b2&type=all', 0)
    assert_hitcount('query=sddocname:blogpost&username=c3&type=all', 0)
  end

  def test_friends_filter_plugin
    add_bundle(selfdir + "FriendFilterSearcher.java")
    deploy_app(SearchApp.new.
               sd(selfdir+"friendslist.sd").
               sd(selfdir+"blogpost.sd").
               search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.FriendFilterSearcher"))))

    start
    feed(:file => selfdir+"docs.json")
    wait_for_hitcount("sddocname:friendslist", 2)
    wait_for_hitcount("sddocname:blogpost", 12)

  # save_result("tracelevel=1&query=title:foo",                         selfdir+"result.foo1.json")
  # save_result("tracelevel=1&query=title:foo&username=default",        selfdir+"result.foo2.json")
  # save_result("tracelevel=1&query=title:foo&username=arnej",          selfdir+"result.foo3.json")
  # save_result("tracelevel=1&query=title:foo&username=paris+hilton",   selfdir+"result.foo4.json")

    assert_result('query=title:foo&type=all',                         selfdir+"result.foo1.json")
    assert_result('query=title:foo&username=default&type=all',        selfdir+"result.foo2.json")
    assert_result('query=title:foo&username=arnej&type=all',          selfdir+"result.foo3.json")
    assert_result('query=title:foo&username=paris+hilton&type=all',   selfdir+"result.foo4.json")
  end

  def teardown
    stop
  end

end
