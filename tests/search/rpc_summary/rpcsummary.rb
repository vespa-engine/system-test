# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class RpcSummary < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test that we can fetch summary both with rpc and with deprecated packet protocol.")
  end

  def test_rpcsummary
    if @valgrind
      deploy_app(SearchApp.new.sd(selfdir+"test.sd").sd(selfdir+"testb.sd").config(ConfigOverride.new("search.config.cluster").add("maxQueryCacheTimeout", 1000.0)))
    else
      deploy_app(SearchApp.new.sd(selfdir+"test.sd").sd(selfdir+"testb.sd"))
    end
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.xml")
    feed_and_wait_for_docs("testb", 2, :file => selfdir + "feedb.xml")
    verify_doctype("test")
    verify_doctype("testb")
  end

  def verify_doctype(type)
    query="query=sddocname:#{type}&summary=s1&ranking=rank1"
    assert_result(query, selfdir + "result.json", nil, ["id", "f1", "relevancy"])
    assert_result(query, selfdir + "result.json", nil, ["id", "f1", "relevancy", "summaryfeatures"])

    # Silently ignore the dispatch.summaries setting as it won't work in this case
    assert_result(query + "&dispatch.summaries=true", selfdir + "result.json", nil, ["id", "f1", "relevancy", "summaryfeatures"])

    assert_result(query + "&dispatch.summaries=true&ranking.queryCache", selfdir + "result.json", nil, ["id", "f1", "relevancy", "summaryfeatures"])
    gquery="#{query}&select=all(group(id) each(each(output(summary(s1)))))&hits=0"
    assert_xml_result_with_timeout(2.0, gquery, selfdir + "#{type}-group.xml")
    assert_xml_result_with_timeout(2.0, gquery + "&dispatch.summaries=true&ranking.queryCache", selfdir + "#{type}-group.xml")
  end

  def teardown
    stop
  end

end
