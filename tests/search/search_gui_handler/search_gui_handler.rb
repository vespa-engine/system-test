# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'net/http'

class SearchGUIHandlerTest < SearchTest

  def setup
    set_owner("hhoiness")
    set_description("Test GUIHandler")
  end

  def test_search_gui_handler
    deploy_app(SearchApp.new.
        sd(SEARCH_DATA+"music.sd"))
    start

    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    assert_hitcount("query=country", 1)

    container = vespa.container.values.first
    result = container.search("/querybuilder/")

    assert_match /buildFromJSON/, result.xmldata

  end

  def teardown
    stop
  end
end