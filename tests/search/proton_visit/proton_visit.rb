
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class ProtonVisitDemo < SearchTest

  def setup
    set_owner("havardpe")
    set_description("Automatic demo of end-to-end visiting of documents with proton as persistence layer")
  end

  def make_app
    app = SearchApp.new
    app.storage_clusters.push(StorageCluster.new('search').default_group.sd(SEARCH_DATA + 'music.sd'))
    app.sd(SEARCH_DATA + 'music.sd').no_search()
    app
  end

  def test_proton_feed_and_visit
    deploy_app(make_app)
    start
    feed(:file => SEARCH_DATA+"music.10.json", :timeout => 240)
    vespa.storage["storage"].assert_document_count(10)
    vespa.adminserver.execute("vespa-visit")
  end

  def teardown
    stop
  end

end
