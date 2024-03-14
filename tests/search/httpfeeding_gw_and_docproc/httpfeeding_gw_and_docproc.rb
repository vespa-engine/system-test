# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "indexed_streaming_search_test"

class HttpfeedingGwAndDocproc < IndexedStreamingSearchTest
  def setup
    @feed_file_json = selfdir + "../data/simple.docs.3.json"
    @feed_file_tas_json = selfdir + "../data/simple.test-and-set.json"

    set_owner("valerijf")
    set_description("Test feeding through HTTP client API with document processing in same container, ticket 6390014")
  end

  def make_app
    app = SearchApp.new
    app.container(Container.new('default').search(Searching.new))
    container = Container.new('doc-api')
    container.documentapi(ContainerDocumentApi.new)
    container.http(Http.new.server(Server.new('default', 19020)))
    container.docproc(DocumentProcessing.new)
    app.container(container)
    app.sd(selfdir + '../data/simple.sd')
    return app
  end

  def test_feed
    deploy_app(make_app)
    start
    require_that_feeding_with_json_works
    require_that_feeding_with_json_works_tas
  end

  def require_that_feeding_with_json_works
    httpclient_feed(@feed_file_json)
    wait_for_hitcount("query=json", 3)
  end

  def require_that_feeding_with_json_works_tas
    httpclient_feed(@feed_file_tas_json)
    wait_for_hitcount("query=title:school", 0)
    wait_for_hitcount("query=title:basil", 0)
    wait_for_hitcount("query=title:gundam", 0)
    wait_for_hitcount("query=title:onegai", 1)
    wait_for_hitcount("query=title:tindersticks", 1)
  end

  def httpclient_feed(feed_file)
    feedfile(feed_file, {:client => :vespa_feed_client, :route => "indexing", :port => 19020})
  end

  def teardown
    stop
  end
end
