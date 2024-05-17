# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'
require 'app_generator/http'
require 'environment'

class LongQueries < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Test that very long queries work by setting http-server parameters" +
                    "to 131072")

    deploy_app(SearchApp.new.
                   sd(SEARCH_DATA+"music.sd").
                   container(Container.new.
                                 documentapi(ContainerDocumentApi.new).
                                 search(Searching.new).
                                 http(Http.new.
                                          server(Server.
                                                     new("default", Environment.instance.vespa_web_service_port).
                                                     config(ConfigOverride.new("jdisc.http.connector").
                                                                add("requestHeaderSize", "131072"))
                                      )
                             )
               )
    )
    start
  end

  def test_longqueries
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json")

    file = File.new(selfdir+"do.query")
    query = file.read()

    assert_result(query, selfdir+"do.result.json", nil, ["title", "pto", "mid", "surl", "categories", "bgnsellers"])
  end

  def teardown
    stop
  end

end
