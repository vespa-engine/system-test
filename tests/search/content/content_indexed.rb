# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require_relative 'content_smoke_common'

class ContentIndexedSmokeTest < SearchTest

  include ContentSmokeCommon

  def setup
    set_owner('balder')
    set_description('Test basic indexed searching with content setup')
  end

  def test_contentsmoke_indexed
    deploy(selfdir+'singlenode-indexed', SEARCH_DATA+'music.sd')
    start_feed_and_check
  end

  def test_contentsmoke_indexed_get
    deploy(selfdir+'singlenode-indexed', SEARCH_DATA+'music.sd')
    start_feed_and_check
    verify_get
  end

  def test_contentsmoke_indexed_4nodes_redundancy2
    deploy(selfdir+'multinode-indexed', SEARCH_DATA+'music.sd')
    start_feed_and_check
    verify_get
  end

  def test_contentsmoke_proton_only
    deploy(selfdir+'singlenode-proton-only', SEARCH_DATA+'music.sd')
    start
    feed_only
    verify_get
  end

  def teardown
    stop
  end

end
