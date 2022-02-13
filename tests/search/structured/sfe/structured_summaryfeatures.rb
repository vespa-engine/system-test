# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'app_generator/container_app'

class StructuredSummaryFeaturesTest < SearchTest

  def setup
    set_owner("arnej")
    set_description("search structured data in a Searcher")
  end

  def test_feature_data
    add_bundle(selfdir + "SimpleTestSearcher.java")
    searcher = Searcher.new("com.yahoo.test.SimpleTestSearcher")
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         docproc(DocumentProcessing.new).
                         search(Searching.new.
                                chain(Chain.new("default", "vespa").add(searcher)))).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"sfdtest.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("sfdtest", 3, :file => selfdir+"feed-2.xml")
    # save_result("query=title:word",                         selfdir+"result.wd.json")
    assert_result("query=title:word",                         selfdir+"result.wd.json")
    assert_result("query=title:word&ranking.queryCache=true", selfdir+"result.wd.json")

    grp = "select=all(group(quality)each(max(3)each(output(summary()))))"
    # save_result("query=title:word&#{grp}", selfdir+"result.wd-group.json")
    assert_result("query=title:word&#{grp}", selfdir+"result.wd-group.json")
    assert_result("query=title:word&#{grp}&ranking.queryCache=true", selfdir+"result.wd-group.json")
  end

  def teardown
    stop
  end

end
