# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "indexed_search_test"

class HttpClientApiTest < IndexedSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test feeding through HTTP client API")
    deploy_app(SearchApp.new.
                 container(Container.new.
                             documentapi(ContainerDocumentApi.new).
                             search(Searching.new)).
                 cluster(SearchCluster.new("simple").sd(selfdir+"../data/simple.sd")))
    start
  end

  def test_feed
    port = Environment.instance.vespa_web_service_port
    feedfile(selfdir + "../data/simple.docs.3.xml", {:client => :vespa_feeder, :route => "indexing", :port => port})
    wait_for_hitcount("query=sddocname:simple", 3)

    feedfile(selfdir + "simple.docs.error.5.4.xml", {:client => :vespa_feeder, :route => "indexing", :port => port})
    wait_for_hitcount("query=sddocname:simple", 5)
  end

  def teardown
    stop
  end

end
