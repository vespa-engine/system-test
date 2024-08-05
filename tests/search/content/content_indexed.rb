# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require_relative 'content_smoke_common'

class ContentIndexedSmokeTest < IndexedOnlySearchTest

  include ContentSmokeCommon

  def setup
    set_owner('balder')
    set_description('Test basic indexed searching with content setup')
  end

  def self.final_test_methods
    [ 'test_contentsmoke_proton_only' ]
  end

  def test_contentsmoke_indexed
    deploy_app(SearchApp.new.sd(SEARCH_DATA + 'music.sd'))
    start_feed_and_check
  end

  def test_contentsmoke_indexed_get
    deploy_app(SearchApp.new.sd(SEARCH_DATA + 'music.sd'))
    start_feed_and_check
    verify_get
  end

  def test_contentsmoke_indexed_4nodes_redundancy2
    deploy_app(SearchApp.new.sd(SEARCH_DATA + 'music.sd').num_parts(4))
    start_feed_and_check
    verify_get
  end

  def test_contentsmoke_proton_only
    @params = { :search_type => "NONE" }
    app = SearchApp.new
    app.storage_clusters.push(StorageCluster.new("search").default_group.sd(SEARCH_DATA + 'music.sd'))
    app.sd(SEARCH_DATA + 'music.sd')
    deploy_app(app)
    start
    feed_only
    verify_get
  end

  def teardown
    stop
  end

end
