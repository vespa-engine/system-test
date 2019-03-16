# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class BoldChinese < IndexedSearchTest

  def setup
    set_owner("johansen")
    set_description("Test bolding (Highlighting of query-terms)")
    deploy_app(SearchApp.new.sd(selfdir+"cjk.sd"))
    start
  end

  def test_bold_chinese
    feed_and_wait_for_docs("cjk", 34, :file => SEARCH_DATA+"dynteaser.32.xml")

    filter = /name="content"/
    puts "Query: chinese text"
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&language=zh-hans", selfdir+"result.1", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&bolding=off&language=zh-hans", selfdir+"result.2", filter)
    assert_result_matches("language=zh-hans&query=content:%E5%8F%AF%E4%BB%A5%E6%9C%89%E7%90%86%E7%94%B1%E8%AE%A4%E4%B8%BA%E7%8E%B0%E8%A1%8C%E5%90%84%E7%A7%8D%E8%A7%84%E5%88%99%E9%83%BD%E6%9C%AA%E8%83%BD%E5%BB%BA%E7%AB%8B%E8%B5%B7%E6%9C%80%E7%BB%88%E5%B1%80%E9%9D%A2%E7%9A%84%E6%A6%82%E5%BF%B5", selfdir+"result.3", filter)

    puts "same, test caching effect"
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&language=zh-hans", selfdir+"result.1", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&language=zh-hans", selfdir+"result.1", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&bolding=off&language=zh-hans", selfdir+"result.2", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&bolding=off&language=zh-hans", selfdir+"result.2", filter)
    assert_result_matches("language=zh-hans&query=content:%E5%8F%AF%E4%BB%A5%E6%9C%89%E7%90%86%E7%94%B1%E8%AE%A4%E4%B8%BA%E7%8E%B0%E8%A1%8C%E5%90%84%E7%A7%8D%E8%A7%84%E5%88%99%E9%83%BD%E6%9C%AA%E8%83%BD%E5%BB%BA%E7%AB%8B%E8%B5%B7%E6%9C%80%E7%BB%88%E5%B1%80%E9%9D%A2%E7%9A%84%E6%A6%82%E5%BF%B5", selfdir+"result.3", filter)
    assert_result_matches("language=zh-hans&query=content:%E5%8F%AF%E4%BB%A5%E6%9C%89%E7%90%86%E7%94%B1%E8%AE%A4%E4%B8%BA%E7%8E%B0%E8%A1%8C%E5%90%84%E7%A7%8D%E8%A7%84%E5%88%99%E9%83%BD%E6%9C%AA%E8%83%BD%E5%BB%BA%E7%AB%8B%E8%B5%B7%E6%9C%80%E7%BB%88%E5%B1%80%E9%9D%A2%E7%9A%84%E6%A6%82%E5%BF%B5", selfdir+"result.3", filter)

    puts "same, test nocache"
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&language=zh-hans&nocache", selfdir+"result.1", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&language=zh-hans&nocache", selfdir+"result.1", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&bolding=off&language=zh-hans&nocache", selfdir+"result.2", filter)
    assert_result_matches("query=content:%E5%9B%A0%E4%B8%BA%E6%A3%8B%E7%9B%98&bolding=off&language=zh-hans&nocache", selfdir+"result.2", filter)
    assert_result_matches("language=zh-hans&query=content:%E5%8F%AF%E4%BB%A5%E6%9C%89%E7%90%86%E7%94%B1%E8%AE%A4%E4%B8%BA%E7%8E%B0%E8%A1%8C%E5%90%84%E7%A7%8D%E8%A7%84%E5%88%99%E9%83%BD%E6%9C%AA%E8%83%BD%E5%BB%BA%E7%AB%8B%E8%B5%B7%E6%9C%80%E7%BB%88%E5%B1%80%E9%9D%A2%E7%9A%84%E6%A6%82%E5%BF%B5&nocache", selfdir+"result.3", filter)
    assert_result_matches("language=zh-hans&query=content:%E5%8F%AF%E4%BB%A5%E6%9C%89%E7%90%86%E7%94%B1%E8%AE%A4%E4%B8%BA%E7%8E%B0%E8%A1%8C%E5%90%84%E7%A7%8D%E8%A7%84%E5%88%99%E9%83%BD%E6%9C%AA%E8%83%BD%E5%BB%BA%E7%AB%8B%E8%B5%B7%E6%9C%80%E7%BB%88%E5%B1%80%E9%9D%A2%E7%9A%84%E6%A6%82%E5%BF%B5&nocache", selfdir+"result.3", filter)

  end

  def teardown
    stop
  end

end
