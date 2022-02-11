# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class CoordinatesBug < SearchTest

  def setup
    set_owner("arnej")
    set_description("verify bugfix")
  end


  def test_bug6858688_fixed
    add_bundle(selfdir + "DebugDataSearcher.java")
    searcher = Searcher.new("com.yahoo.test.DebugDataSearcher")
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new.
                                chain(Chain.new("default", "vespa").add(searcher))).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"coords.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("coords", 1, :file => selfdir+"feed.xml")
    semicolon = "%3B"

    geo = "pos.ll=N63.4#{semicolon}E10.4"
    attr = "pos.attribute=p2"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"pizza2.json")
    assert_result("query=title:pizza&#{add}", selfdir+"pizza2.json")
    add = geo + "&" + attr + "&summary=foo"
    #     save_result("query=title:pizza&#{add}", selfdir+"pizza2_foo.json")
    assert_result("query=title:pizza&#{add}", selfdir+"pizza2_foo.json")

    geo = "pos.ll=N50.0#{semicolon}E20.0"
    attr = "pos.attribute=p4"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"pizza4.json")
    assert_result("query=title:pizza&#{add}", selfdir+"pizza4.json")
    add = geo + "&" + attr + "&summary=foo"
    #     save_result("query=title:pizza&#{add}", selfdir+"pizza4_foo.json")
    assert_result("query=title:pizza&#{add}", selfdir+"pizza4_foo.json")

    geo = "pos.ll=N51.5#{semicolon}W0.1"
    attr = "pos.attribute=p5"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"pizza5.json")
    assert_result("query=title:pizza&#{add}", selfdir+"pizza5.json")
    add = geo + "&" + attr + "&summary=foo"
    #     save_result("query=title:pizza&#{add}", selfdir+"pizza5_foo.json")
    assert_result("query=title:pizza&#{add}", selfdir+"pizza5_foo.json")

    #     save_result("query=title:pizza&summary=test_summary", selfdir+"pizza_ts.json")
    assert_result("query=title:pizza&summary=test_summary", selfdir+"pizza_ts.json")

    #     save_result("query=title:pizza", selfdir+"pizza_all.json")
    assert_result("query=title:pizza", selfdir+"pizza_all.json")

  end

  def teardown
    stop
  end

end
