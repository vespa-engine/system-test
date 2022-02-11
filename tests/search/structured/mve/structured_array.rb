# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'app_generator/container_app'

class StructuredArrayTest < SearchTest

  def setup
    set_owner("arnej")
    set_description("search structured data in a Searcher")
  end

  def test_multivalue_data
    add_bundle(selfdir + "SimpleTestSearcher.java")
    searcher = Searcher.new("com.yahoo.test.SimpleTestSearcher")
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new.
                                chain(Chain.new("default", "vespa").add(searcher))).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"mvdtest.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("mvdtest", 1, :file => selfdir+"feed-1.xml")
    # save_result("query=titles:%22slim%20shady%22", selfdir+"result.ss.json")
    assert_result("query=titles:%22slim%20shady%22", selfdir+"result.ss.json")
  end

  def teardown
    stop
  end

end
