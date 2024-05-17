# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'app_generator/http'

class Many_Services < IndexedStreamingSearchTest

  def timeout_seconds
    return 1800
  end

  def setup
    set_owner("musum")
    set_description("Test that it's possible to have many services of the same type on one node.")
  end

  def test_many_services_realtime
    deploy_app(SearchApp.new.slobrok("node1").slobrok("node1").
                 container(Container.new("foo").
                             documentapi(ContainerDocumentApi.new).
                             search(Searching.new).
                             http(Http.new.
                                  server(Server.new("foo-server", 4080)))).
                      container(Container.new("bar").
                             search(Searching.new).
                             http(Http.new.
                                  server(Server.new("bar-server", 4090)))).
                      cluster(SearchCluster.new.sd(selfdir+"music.sd").
                        redundancy(2).num_parts(3)))
    vespa.start

    wait_until_ready(900)
    push_realtime("music.10.ranked.json")

    query = "query=sddocname:music&format=xml"
    for qrs_id in (0..vespa.qrserver.length-1)
      wait_for_hitcount(query, 10, 300, qrs_id)
    end
    result_file = dirs.tmpdir + "music.10.ranked.result.xml"
    save_result(query, result_file)

    for qrs_id in (0..vespa.qrserver.length-1)
      # wait for qrs to notice new index
      for retries in (1..60)
        puts "Checking qrs #{qrs_id} try #{retries}"
        isdone = false
        begin
          result = search(query, qrs_id)
          if 10 == result.hitcount
            isdone = true
          else
            puts "not ready, only #{result.hitcount} hits at: " + `date`.chomp
          end
          if result.xml.elements["error"]
            puts "problem: #{result.xml.elements["error"]} at: " + `date`.chomp
            isdone = false
          end
          break if isdone
          sleep 1
        rescue Exception => e
          puts "problem with search via qrs (will retry), ignoring: "+e
          sleep 1
        end
      end
      assert_resultsets(result, result_file)
    end	
  end

  def push_realtime(file)
    feedfile(selfdir+file, :port => 4080)
  end

  def assert_resultsets(result, savedresultfile)
    saved_result = create_resultset(savedresultfile)

    # check that the hitcount is equal to the saved hitcount
    assert_equal(saved_result.hitcount, result.hitcount, \
                 "Query returned unexpected number of hits.")

    # check that the hits are equal to the saved hits
    saved_result.hit.each_index do |i|
      saved_result.hit[i].check_equal(result.hit[i])
    end
  end

  def teardown
    stop
  end
end
