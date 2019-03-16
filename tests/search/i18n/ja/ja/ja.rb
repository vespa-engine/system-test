# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Ja < IndexedSearchTest
  def setup
    set_owner("johansen")
    set_description("Test of Japanese indexing")
    deploy_app(SearchApp.new.sd(selfdir+"cjk.sd"))
    start
  end

  def test_japanese
    feed_and_wait_for_docs("cjk", 33, :file => SEARCH_DATA+"cjk.30.xml")
    wait_for_hitcount("query=sddocname:cjk", 33)

    puts "Query: One term queries, japanese"
    assert_hitcount("query=content:%E5%AE%8C%E6%88%90&language=ja", 1)

    puts "Query: Multiple term queries, japanese"
    assert_hitcount("query=content:%E9%9F%B3%E5%A3%B0%E3%81%AA%E3%81%A9%E3%81%AE&language=ja", 1)

    # text below means approx:
    # %E8%87%AA%E5%88%86 "your"   %E3%81%AE sound 'no'
    # %E6%99%82%E8%A8%88 "clock"  %E3%81%8C sound 'ka'
    # %E6%AD%A2%E3%81%BE%E3%82%8A "stopping" + 'ma' + 'ri' ~= "stops"

    assert_hitcount("query=content:%E8%87%AA%E5%88%86%E3%81%AE%E6%99%82%E8%A8%88%E3%81%8C%E6%AD%A2%E3%81%BE%E3%82%8A&language=ja", 1)

    puts "Query: Large cjk text, japanese"
    assert_hitcount("query=content:%E3%80%81%E3%83%96%E3%82%B6%E3%83%BC%E9%9F%B3%E3%80%81%E9%9F%B3%E5%A3%B0%E3%81%AA%E3%81%A9%E3%81%AE%E6%A9%9F%E8%83%BD%E3%81%8C%E3%81%A4%E3%81%84%E3%81%9F%E6%99%82%E8%A8%88%E3%82%82%E3%81%82%E3%82%8A%E3%80%81%E3%81%BE%E3%81%9F%E6%AC%A7%E7%B1%B3%E3%82%84%E4%B8%96%E7%95%8C%E3%82%A2%E3%83%9E%E3%83%81%E3%83%A5%E3%82%A2%E5%9B%B2%E7%A2%81%E5%A4%A7%E4%BC%9A%E3%81%AA%E3%81%A9%E3%81%A7%E6%8E%A1%E7%94%A8%E3%81%95%E3%82%8C%E3%81%A6%E3%81%84%E3%82%8B%E3%80%8C content:%E3%82%AB%E3%83%8A%E3%83%80%E6%96%B9%E5%BC%8F%E3%80%8D&language=ja", 1)
  end

  def teardown
    stop
  end

end
