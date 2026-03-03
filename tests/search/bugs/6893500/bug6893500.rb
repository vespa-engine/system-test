# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'
require 'app_generator/container_app'
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'json'

class MapInSummaryBug < IndexedStreamingSearchTest
  def setup
    set_owner("arnej")
    set_description("verify bugfix")
  end

  def test_bug6893500_fixed
    add_bundle(selfdir + "DebugDataSearcher.java")
    searcher = Searcher.new("com.yahoo.test.DebugDataSearcher")
    deploy_app(
      SearchApp.new.
        cluster_name("multitest").
        sd(selfdir+"withmap.sd").
        container(Container.new("mycc").
                    documentapi(ContainerDocumentApi.new).
                    search(Searching.new.
                             chain(Chain.new("default", "vespa").add(searcher))).
                    docproc(DocumentProcessing.new)))
    start
    feed_and_wait_for_docs("withmap", 1, :file => selfdir+"feed.json")

    result = search("query=title:pizza")
    fields_to_check = ['bad_map', 'good_map', 'meta_tags']

    expected_fields = {
      "good_map" => {
        "hitchhiker" => { "bar" => "fortytwo", "foo" => 42 },
        "adams"      => { "bar" => "one",       "foo" => 1  }
      },
      "bad_map" => {
        "7042" => { "name" => "lademoen",      "addr" => "trondheim",                 "postcode" => 7042 },
        "42"   => { "name" => "the restaurant","addr" => "at the end of the universe","postcode" => 42   }
      },
      "meta_tags" => { "789" => "foobar", "123" => "foo", "456" => "bar" }
    }

    result_fields = JSON.parse(result.xmldata)["root"]["children"][0]["fields"]
    fields_to_check.all? { |f|
      assert_equal(result_fields[f], expected_fields[f]) }
  end

end
