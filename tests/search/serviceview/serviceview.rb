 # Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ServiceView < SearchTest

  def setup
    set_owner("musum")
    set_description("Test links in serviceview work")
    deploy_app(SearchApp.new.
        cluster_name("serviceview").
        sd(SEARCH_DATA+"music.sd"))
    start
  end

  def can_share_configservers?(method_name=nil)
    false
  end

  def test_serviceview
    feed(:file => SEARCH_DATA+"music.10.xml", :timeout => 240)
    wait_for_hitcount("query=sddocname:music", 10)
    configserver = vespa.configservers["0"].name
    httpport = vespa.configservers["0"].ports[1]
    app_view = http_request( \
        URI("http://#{configserver}:#{httpport}/serviceview/v1"), \
        {})
    assert_equal(200, app_view.code.to_i)
    model = get_json(app_view)
    model["clusters"].each do |cluster|
      cluster["services"].each do |service|
        link = service["url"]
        puts("Checking #{link}\n")
        state = http_request( \
            URI(link), \
            {})
        assert_equal(200, state.code.to_i)
      end
    end
  end

  def teardown
    stop
  end

end
