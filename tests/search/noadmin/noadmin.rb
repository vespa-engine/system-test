# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class NoAdminInServices < IndexedStreamingSearchTest

  class NoAdmin < Admin
    def to_xml(indent)
      ''
    end
  end

  def setup
    set_owner("musum")
    set_description("Test that having no admin element in services.xml works")
  end

  def test_no_admin_search
    deploy_app(SearchApp.new.admin(NoAdmin.new).sd(SEARCH_DATA + 'music.sd'))
    start_and_feed
  end

  def start_and_feed
    start
    feed(:file => SEARCH_DATA+"music.10.json")
    wait_for_hitcount("query=sddocname:music", 10)
  end

  def teardown
    stop
  end

end
