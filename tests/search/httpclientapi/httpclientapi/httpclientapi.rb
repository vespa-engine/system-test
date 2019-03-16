# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "indexed_search_test"

class HttpClientApiTest < IndexedSearchTest

  def setup
    set_owner("valerijf")
    set_description("Test feeding through HTTP client API")
    deploy_app(SearchApp.new.gateway("node1").
        cluster(SearchCluster.new("simple").sd(selfdir+"../data/simple.sd")))
    start
  end

  def test_feed
    feedfile(selfdir + "../data/simple.docs.3.xml", {:client => :vespa_http_client, :route => "indexing"})
    wait_for_hitcount("query=sddocname:simple", 3)

    feedfile(selfdir + "simple.docs.error.5.4.xml", {:client => :vespa_http_client, :route => "indexing"})
    wait_for_hitcount("query=sddocname:simple", 5)
  end

  def teardown
    stop
  end

end
