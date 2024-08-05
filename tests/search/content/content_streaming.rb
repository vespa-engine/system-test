# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'
require_relative 'content_smoke_common'

class ContentStreamingSmokeTest < StreamingSearchTest

  include ContentSmokeCommon

  def setup
    set_owner('balder')
    set_description('Test basic streaming searching with content setup')
  end

  def test_contentsmoke_streaming
    deploy_app(SearchApp.new.sd(SEARCH_DATA + 'music.sd'))
    @node = vespa.storage['search'].storage['0']
    start_feed_and_check
    verify_get
  end

  def test_contentsmoke_proton_streaming
    app = SearchApp.new
    app.storage_clusters.push(StorageCluster.new("search").default_group)
    app.sd(SEARCH_DATA + 'music.sd').provider('PROTON')
    deploy_app(app)
    @node = nil
    start
    feed_only
    verify_get
    check
  end

  def test_contentsmoke_dummy_streaming
    app = SearchApp.new
    app.storage_clusters.push(StorageCluster.new("search").default_group)
    app.sd(SEARCH_DATA + 'music.sd').provider('DUMMY')
    deploy_app(app)
    @node = nil
    start_feed_and_check
    verify_get
  end

  def teardown
    stop
  end

end
