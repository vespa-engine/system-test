# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'environment'

class VipStatus < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Check VIP status reporting works as expected when deploying in different ways.")
    @valgrind=false
    @vip_status_file = dirs.tmpdir + "/status2.html"
  end

  def test_without_fileserverport_with_disc_access
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").config(
        ConfigOverride.new("container.core.vip-status")\
            .add("accessdisk", "true")\
            .add("statusfile", @vip_status_file)))

    # Create file before starting services
    create_vip_status_file
    start
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json", :cluster => "music")
    sleep 2

    assert_response_code_from_vip_handler("200")
    remove_vip_status_file
    assert_response_code_from_vip_handler("404")
  end

  def test_without_fileserverport_without_file
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").config(
        ConfigOverride.new("container.core.vip-status")\
            .add("accessdisk", "true")\
            .add("statusfile", "/ThisFileShouldNotExist")))
    start
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json", :cluster => "music")
    sleep 2

    #wget (search port) status.html, check status 404, fail test otherwise
    assert_response_code_from_vip_handler("404")
  end

  def test_without_fileserverport_without_disc_access
    deploy_app(SearchApp.new.sd(selfdir+"music.sd"))
    start
    feed_and_wait_for_docs("music", 1, :file => SEARCH_DATA+"music.1.json", :cluster => "music")
    sleep 2

    assert_response_code_from_vip_handler("200")

    #this should run into no JDisc binding => 404
    assert_response_code_from_vip_handler("404", "/some_file.html")
  end

  def create_vip_status_file
    vespa.container.values.first.writefile("OK", @vip_status_file)
  end

  def remove_vip_status_file
    vespa.container.values.first.removefile(@vip_status_file)
  end

  def assert_response_code_from_vip_handler(expected_response_code, path="/status.html")
    qrserver = vespa.container.values.first
    s_name = qrserver.name
    s_port = qrserver.http_port

    #netcat to search port, fail test otherwise
    assert_nothing_raised() { TCPSocket.new(s_name, s_port) }

    assert_nothing_raised() {
      response = https_client.get(s_name, s_port, path)
      assert_equal(expected_response_code, response.code);
    }
  end

  def teardown
    qrserver = vespa.container.values.first
    qrserver.execute("rm -rf #{Environment.instance.vespa_home}/share/qrsdocs") if qrserver
    stop
  end

end
