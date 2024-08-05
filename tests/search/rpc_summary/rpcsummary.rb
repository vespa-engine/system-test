# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class RpcSummary < IndexedStreamingSearchTest

  def setup
    set_owner("balder")
    set_description("Test that we can fetch summary both with and without ranking.queryCache.")
  end

  def test_rpcsummary
    if @valgrind
      deploy_app(SearchApp.new.sd(selfdir+"test.sd").sd(selfdir+"testb.sd").config(ConfigOverride.new("search.config.cluster").add("maxQueryCacheTimeout", 1000.0)))
    else
      deploy_app(SearchApp.new.sd(selfdir+"test.sd").sd(selfdir+"testb.sd"))
    end
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "feed.json")
    feed_and_wait_for_docs("testb", 2, :file => selfdir + "feedb.json")
    verify_doctype("test")
    verify_doctype("testb")
  end

  def verify_doctype(type)
    query="query=sddocname:#{type}&summary=s1&ranking=rank1"
    assert_result(query, selfdir + "result.json", nil, ["id", "f1", "relevancy"])
    assert_result(query, selfdir + "result.json", nil, ["id", "f1", "relevancy", "summaryfeatures"])

    assert_result(query + "&ranking.queryCache", selfdir + "result.json", nil, ["id", "f1", "relevancy", "summaryfeatures"])
    restrict = is_streaming ? "&restrict=#{type}" : ""
    gquery="#{query}&select=all(group(id) each(each(output(summary(s1)))))#{restrict}&hits=0"
    assert_xml_result_with_timeout(2.0, gquery, selfdir + "#{type}-group.xml")
    assert_xml_result_with_timeout(2.0, gquery + "&ranking.queryCache", selfdir + "#{type}-group.xml")
  end

  def teardown
    stop
  end

end
