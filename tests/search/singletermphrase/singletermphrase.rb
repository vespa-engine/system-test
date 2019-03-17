# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class SingleTermPhrase < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Check single term phrases are handled OK")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
  end

  def test_singletermphrase
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.xml")

    puts "Query: Querying, old problem query"
    assert_result_matches("query=CET-4%E6%88%90%E7%BB%A9&tracelevel=2&language=zh-hans",
                          selfdir+"first.result",
                          "<p>Detected language: ")

    puts "Query: Querying, invalid UTF-8"
    assert_result_matches("query=%C3%83%C2%98%C3%82%C2%B5%C3%83%C2%99%C3%82%C2%88%C3%83%C2%98%C3%82%C2%B1&tracelevel=2&language=zh-hans",
                          selfdir+"second.result",
                          "<p>Detected language: ")

  end

  def teardown
    stop
  end

end
