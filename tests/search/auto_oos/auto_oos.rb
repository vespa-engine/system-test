# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class AutomaticOutOfServiceTest < SearchTest

  def setup
    set_owner("arnej")
    set_description("Test basic vip handling using /status.html")
  end

  def test_multicluster_stop_nodes
    deploy_app(SearchApp.new.
        num_parts(2).
        cluster(
            SearchCluster.new("bluemusic").sd(SEARCH_DATA + "music.sd").
            num_parts(2).
            doc_type("music", "music.mid==2")).
        cluster(
            SearchCluster.new("orangemusic").sd(SEARCH_DATA + "music.sd").
            num_parts(2).
            doc_type("music", "music.mid==3")))
    start
    assert_response_code_from_vip_handler("200")

    feed_and_wait_for_docs("music", 2, :file => selfdir + "music.2.xml")
    assert_response_code_from_vip_handler("200")

    stop_searchnodes("orangemusic")
    # will be considered down after 10 seconds
    sleep 15
    assert_response_code_from_vip_handler("200")

    stop_searchnodes("bluemusic")
    assert_response_code_from_vip_handler("404")

    start_searchnodes("bluemusic")
    assert_response_code_from_vip_handler("404")

    start_searchnodes("orangemusic")
    assert_response_code_from_vip_handler("200")
  end

  def stop_searchnodes(clustername)
    vespa.search[clustername].searchnode.values.each do |node|
      node.stop
    end
  end

  def start_searchnodes(clustername)
    vespa.search[clustername].searchnode.values.each do |node|
      node.start
    end
  end

  def assert_response_code_from_vip_handler(expected_response_code, path="/status.html")
    s_name = vespa.container.values.first.name
    s_port = vespa.container.values.first.http_port

    #netcat to search port, fail test otherwise
    assert_nothing_raised() { TCPSocket.new(s_name, s_port) }

    assert_nothing_raised() { 
      got = "nothing good"
      trynum = 0
      while ((trynum < 120) && (got != expected_response_code)) do
        trynum += 1
        sleep 1
        response = https_client.get(s_name, s_port, path)
        got = response.code
        puts "response code #{response.code} on try #{trynum} (expecting #{expected_response_code})"
      end
      assert_equal(expected_response_code, response.code)
    }
  end


  def teardown
    stop
  end

end
