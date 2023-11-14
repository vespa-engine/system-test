# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'streaming_search_test'
require 'search/rankfeatures/rankfeatures_base'


class RankFeaturesStreaming < StreamingSearchTest

  include RankFeaturesBase

  def test_dump
    set_description("Test that the expected rank features are dumped using streaming search")
    deploy_app(SearchApp.new.sd(selfdir + "streaming/dump.sd"))
    start
    feed_and_wait_for_docs("dump", 1, :file => selfdir+"dumpss.xml")

    expected = []
    File.open(selfdir + "dumpss.txt", "r").each do |line|
      expected.push(line.strip)
    end

    assert_dump(expected, "a:a")

    extra = ["term(5).connectedness", "term(5).significance", "term(5).weight"]
    assert_dump(expected + extra, "a:a&ranking=extra")
    assert_dump(extra,            "a:a&ranking=ignore")
  end

end
