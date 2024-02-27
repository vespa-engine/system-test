# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'

class MapInSummaryBug < SearchTest

  def setup
    set_owner("arnej")
    set_description("verify bugfix")
  end

  def test_bug6893500_fixed
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
                      sd(selfdir+"withmap.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("withmap", 1, :file => selfdir+"feed.xml")

    assert_result("query=title:pizza", selfdir+"pizza.json")
  end

  def teardown
    stop
  end

end
