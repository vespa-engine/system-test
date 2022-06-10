# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'
require 'search/proton/mixed_feed_generator'
require 'securerandom'

class ProtonTest < IndexedSearchTest
  include MixedFeedGenerator

  def setup
    set_owner("geirst")
  end

  def self.final_test_methods
    ["test_proton_summary_refeed"]
  end

  def test_proton_restart
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs("test", 2, :file => selfdir + "docs.xml")

    # single term queries
    assert_hitcount('query=title:test&nocache&type=all', 2)
    vespa.search["search"].first.stop
    vespa.search["search"].first.start
    wait_for_hitcount('query=sddocname:test&nocache&type=all', 2)
    assert_hitcount('query=title:test&nocache&type=all', 2)
  end

  def test_proton_feeding
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    run_proton_feeding_test
  end

  def run_proton_feeding_test
    puts "Initial feed"
    feed_and_wait_for_docs("test", 2, :file => selfdir + "docs.xml")
    assert_hitcount('query=title:third&nocache&type=all', 0)
    assert_hitcount('query=sattr:third&nocache&type=all', 0)
    assert_hitcount('query=title:title&nocache&type=all', 2)

    puts "Feed 1 extra document"
    feed(:file => selfdir + "docs.2.xml") # add 1 extra document
    assert_hitcount('query=sddocname:test&nocache&type=all', 3)
    assert_hitcount('query=title:third&nocache&type=all', 1)
    assert_hitcount('query=sattr:third&nocache&type=all', 1)
    assert_hitcount('query=title:title&nocache&type=all', 3)
    assert_hitcount('query=title:test&nocache&type=all', 2)
    fields = ["sddocname", "title", "body", "sattr", "iattr"]
    assert_result('query=sddocname:test&nocache&type=all', selfdir + "docs.all.2.result.json", "iattr", fields)

    puts "Refeed first document"
    feed(:file => selfdir + "docs.3.xml") # replace first document
    assert_hitcount('query=title:refeedtitle&nocache&type=all', 1)
    assert_hitcount('query=title:first&nocache&type=all', 1)
    assert_hitcount('query=sattr:refeedfirst&nocache&type=all', 1)
    assert_hitcount('query=title:title&nocache&type=all', 2)
    assert_hitcount('query=title:test&nocache&type=all', 1)
    # check that we have no remains of old documents
    assert_hitcount('query=title:foo&nocache&type=all', 0)
    assert_hitcount('query=body:bar&nocache&type=all', 0)
    assert_hitcount('query=sattr:first&nocache&type=all', 0)
    assert_hitcount('query=iattr:10&nocache&type=all', 0)
    assert_result('query=sddocname:test&nocache&type=all', selfdir + "docs.all.3.result.json", "iattr", fields)

    puts "Remove second document"
    feed(:file => selfdir + "remove.xml") # remove second document
    assert_hitcount('query=sddocname:test&nocache&type=all', 2)
    assert_hitcount('query=title:second&nocache&type=all', 0)
    assert_hitcount('query=body:second&nocache&type=all', 0)
    assert_hitcount('query=iattr:20&nocache&type=all', 0)
    assert_hitcount('query=sattr:second&nocache&type=all', 0)
    assert_result('query=sddocname:test&nocache&type=all', selfdir + "docs.all.4.result.json", "iattr", fields)

    puts "Remove non-existing document"
    feed(:file => selfdir + "remove.2.xml")
    assert_hitcount('query=sddocname:test&nocache&type=all', 2)
    assert_result('query=sddocname:test&nocache&type=all', selfdir + "docs.all.4.result.json", "iattr", fields)

    puts "Update first document"
    assert_hitcount('query=iattr:1000&nocache&type=all', 0)
    feed(:file => selfdir + "upd.xml")
    assert_hitcount('query=iattr:1000&nocache&type=all', 1)
    assert_result('query=sddocname:test&nocache&type=all', selfdir + "docs.all.5.result.json", "iattr", fields)

    puts "Update non-existing document"
    feed(:file => selfdir + "upd.2.xml", :trace => 1)
    assert_hitcount('query=iattr:1000&nocache&type=all', 1)
    assert_result('query=sddocname:test&nocache&type=all', selfdir + "docs.all.5.result.json", "iattr", fields)
  end

  def nearlyEqual(a, b)
    return false if (a > b + 1.0e-6)
    return false if (a < b - 1.0e-6)
    return true
  end

  def test_proton
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start
    assert_hitcount('query=sddocname:test&nocache&type=all', 0)
    feed_and_wait_for_docs("test", 2, :file => selfdir + "docs.xml")

    puts "single term queries (index fields)"
    assert_hitcount('query=title:test&nocache&type=all', 2)

    assert_hitcount('query=body:first&nocache&type=all', 1)
    assert_hitcount('query=title:first&nocache&type=all', 1)

    assert_hitcount('query=body:second&nocache&type=all', 1)
    assert_hitcount('query=title:second&nocache&type=all', 1)

    assert_hitcount('query=body:title&nocache&type=all', 0)
    assert_hitcount('query=title:title&nocache&type=all', 2)

    assert_hitcount('query=body:body&nocache&type=all', 2)
    assert_hitcount('query=title:body&nocache&type=all', 0)

    assert_hitcount('query=body:foo&nocache&type=all', 0)
    assert_hitcount('query=title:foo&nocache&type=all', 1)

    assert_hitcount('query=body:bar&nocache&type=all', 1)
    assert_hitcount('query=title:bar&nocache&type=all', 0)

    assert_hitcount('query=body:baz&nocache&type=all', 0)
    assert_hitcount('query=title:baz&nocache&type=all', 1)

    assert_hitcount('query=body:cox&nocache&type=all', 1)
    assert_hitcount('query=title:cox&nocache&type=all', 0)

    assert_hitcount('query=bogus:test&nocache&type=all', 0)
    assert_hitcount('query=bogus:test&nocache&type=all', 0)

    assert_hitcount('query=body:bogus&nocache&type=all', 0)
    assert_hitcount('query=title:bogus&nocache&type=all', 0)

    assert_hitcount('query=test&nocache&type=all', 2)
    assert_hitcount('query=foo&nocache&type=all', 1);
    assert_hitcount('query=bar&nocache&type=all', 1);
    assert_hitcount('query=baz&nocache&type=all', 1);
    assert_hitcount('query=cox&nocache&type=all', 1);
    assert_hitcount('query=bogus&nocache&type=all', 0);

    puts "single term queries (attribute fields)"
    assert_hitcount('query=sattr:first&nocache&type=all', 1)
    assert_hitcount('query=sattr:second&nocache&type=all', 1)
    assert_hitcount('query=sattr:bogus&nocache&type=all', 0)
    assert_hitcount('query=iattr:10&nocache&type=all', 1)
    assert_hitcount('query=iattr:20&nocache&type=all', 1)
    assert_hitcount('query=iattr:0&nocache&type=all', 0)
    assert_hitcount('query=iattr:[0%3B9]&nocache&type=all', 0)
    assert_hitcount('query=iattr:[0%3B10]&nocache&type=all', 1)
    assert_hitcount('query=iattr:[9%3B19]&nocache&type=all', 1)
    assert_hitcount('query=iattr:[9%3B20]&nocache&type=all', 2)
    assert_hitcount('query=iattr:[20%3B30]&nocache&type=all', 1)
    assert_hitcount('query=iattr:[21%3B30]&nocache&type=all', 0)
    assert_hitcount('query=iattr:%3E9&nocache&type=all', 2);
    assert_hitcount('query=iattr:%3E10&nocache&type=all', 1);
    assert_hitcount('query=iattr:%3E20&nocache&type=all', 0);
    assert_hitcount('query=iattr:%3C10&nocache&type=all', 0);
    assert_hitcount('query=iattr:%3C11&nocache&type=all', 1);
    assert_hitcount('query=iattr:%3C21&nocache&type=all', 2);

    puts "multi term queries"
    assert_hitcount('query=title:first+body:first&nocache&type=all', 1)
    assert_hitcount('query=title:first+body:second&nocache&type=all', 0)

    assert_hitcount('query=title:second+body:second&nocache&type=all', 1)
    assert_hitcount('query=title:second+body:first&nocache&type=all', 0)

    assert_hitcount('query=title:first+body:second&type=any&nocache&type=all', 2)
    assert_hitcount('query=title:second+body:first&type=any&nocache&type=all', 2)

    assert_hitcount('query=title:first+sattr:first&nocache&type=all', 1)
    assert_hitcount('query=title:first+sattr:second&nocache&type=all', 0)
    assert_hitcount('query=title:first+sattr:second&type=any&nocache&type=all', 2)

    puts "phrase queries"
    assert_hitcount('query=title:%22first test%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22test title%22&nocache&type=all', 2)
    assert_hitcount('query=title:%22title foo%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22first test title%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22test title foo%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22first test title foo%22&nocache&type=all', 1)

    assert_hitcount('query=title:%22second test%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22test title%22&nocache&type=all', 2)
    assert_hitcount('query=title:%22title baz%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22second test title%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22test title baz%22&nocache&type=all', 1)
    assert_hitcount('query=title:%22second test title baz%22&nocache&type=all', 1)

    assert_hitcount('query=title:%22test first%22&nocache&type=all', 0)
    assert_hitcount('query=title:%22title test%22&nocache&type=all', 0)
    assert_hitcount('query=title:%22foo title%22&nocache&type=all', 0)
    assert_hitcount('query=title:%22title test first%22&nocache&type=all', 0)
    assert_hitcount('query=title:%22foo title test%22&nocache&type=all', 0)
    assert_hitcount('query=title:%22foo title test first%22&nocache&type=all', 0)

    assert_hitcount('query=%22first test%22&nocache&type=all', 1)
    assert_hitcount('query=%22second test%22&nocache&type=all', 1)
    assert_hitcount('query=%22title foo%22&nocache&type=all', 1)
    assert_hitcount('query=%22test title%22&nocache&type=all', 2)
    assert_hitcount('query=%22test body%22&nocache&type=all', 2)

    puts "multi term phrase queries"
    assert_hitcount('query=title:%22test title%22+title:foo&nocache&type=all', 1)
    assert_hitcount('query=title:%22test title%22+title:%22title foo%22&nocache&type=all', 1)

    assert_hitcount('query=title:%22test title%22+title:baz&nocache&type=all', 1)
    assert_hitcount('query=title:%22test title%22+title:%22title baz%22&nocache&type=all', 1)

    assert_hitcount('query=%22first test%22+%22second test%22&type=any&nocache&type=all', 2)
    assert_hitcount('query=%22title foo%22+%22body cox%22&type=any&nocache&type=all', 2)
    assert_hitcount('query=%22first title%22+%22second test%22&type=any&nocache&type=all', 1)
    assert_hitcount('query=%22test foo%22+%22body cox%22&type=any&nocache&type=all', 1)

    puts "prefix queries"
#    assert_hitcount('query=b*&nocache&type=all', 2)
#    assert_hitcount('query=ba*&nocache&type=all', 2)
#    assert_hitcount('query=ba*+fi*&nocache&type=all', 1)
#    assert_hitcount('query=title:ba*&nocache&type=all', 1)
#    assert_hitcount('query=title:ba*+title:fi*&type=any&nocache&type=all', 2)

    puts "document summary"
    fields = ["sddocname", "title", "body", "sattr", "iattr", "documentid"]
    assert_result('query=title:first&type=all', selfdir + "docs.first.result.json", nil, fields)
    assert_result('query=title:second&type=all', selfdir + "docs.second.result.json", nil, fields)
    assert_result('query=sddocname:test&type=all', selfdir + "docs.all.result.json", "iattr", fields)
    # non-existing summary class -> error
    result = search('query=title:first&summary=not&type=all')
    assert(result.json)
    puts result.json
    assert(result.json['root'])
    assert(result.json['root'])
    assert(result.json['root']['errors'])
    assert(result.json['root']['errors'][0]['message'])
    assert(result.json['root']['errors'][0]['message'] =~ /invalid.*summary/)

    puts "simple ranking"
    r1 = search('query=title:first&type=all').hit[0].field["relevancy"].to_f
    r2 = search('query=body:first&type=all').hit[0].field["relevancy"].to_f
    puts "rank 1 (title) = #{r1}"
    puts "rank 2 (body) = #{r2}"
    assert(r1 > 0)
    assert(r1 == r2)
    r3 = search('query=first&type=all').hit[0].field["relevancy"].to_f
    puts "rank 3 (title+body) = #{r3}"
    assert(r3 > 0)
    assert(nearlyEqual(r3, r1 + r2), "expected #{r3} == #{r1 + r2}")
    r4 = search('query=bar&type=all').hit[0].field["relevancy"].to_f
    r5 = search('query=body:bar&type=all').hit[0].field["relevancy"].to_f
    assert(r4 > 0)
    assert(r4 == r5)

    puts "simple grouping"
    assert_xml_result_with_timeout(2.0, 'query=sddocname:test&select=all(group(sattr) each(output(count())))&hits=0&type=all', selfdir + "simplegrouping.xml")
  end

  def test_proton_replay
    set_description("Verify that the proton is able to replay the transactionlog on startup")
    deploy_app(SearchApp.new.
                         sd(selfdir+"banana.sd").
                         config(ConfigOverride.new("vespa.config.search.core.proton").
                                               add("pruneremoveddocumentsinterval", 5.0).
                                               add("pruneremoveddocumentsage", 60.0)))
    start
    # Needed for logging messages that are verified later in this test
    vespa.adminserver.logctl("searchnode:proton.server.documentdb", "debug=on,spam=on")
    vespa.adminserver.logctl("searchnode:proton.server.proton",     "debug=on")
    vespa.adminserver.logctl("searchnode:proton.server.feedstates", "debug=on")

    feed(:file => selfdir + "replay.xml")

    wait_for_hitcount("sddocname:banana&nocache", 600)
    wait_for_hitcount("age:%3E#{1000}", 266)

    # Stop
    vespa.search["search"].first.stop
    sleep 2
    vespa.search["search"].first.start

    sleep 10
    # Assert results
    wait_for_hitcount("sddocname:banana&nocache", 600)
    wait_for_hitcount("age:%3E#{1000}", 266)
    last_serial = 123 # serial num is either 1233 or 1234
    first_serial = 1
    assert_log_matches(/.*transactionlog\.replay\.start.*banana.*first":#{first_serial}.*last":#{last_serial}/)
    assert_log_matches(/.*transactionlog\.replay\.progress.*banana.*progress":1\.0.*first":#{first_serial}.*last":#{last_serial}.*current":#{last_serial}/)
    assert_log_matches(/.*transactionlog\.replay\.complete.*banana/)
  end

  def test_proton_feedmany
    @valgrind=false
    set_description("Tests that proton can index a larger feed")
    deploy_app(SearchApp.new.sd("#{selfdir}/banana.sd"))
    start
    numfeed = 100000
    f = File.new("#{dirs.tmpdir}/#{SecureRandom.urlsafe_base64}_mixedfeed.xml", "w")
    numputs, numupdates, numremoves = generate_mixed_feed(f, 0, numfeed, 3, 5)
    f.close
    output = feed(:file => f.path, :timeout => 600)
    wait_for_hitcount("sddocname:banana&nocache", 60000)
  end

  def test_proton_summary_refeed
    set_description("Tests that summary handles refeed after trigger flush. See bug #4780766")
    deploy_app(SearchApp.new.sd(selfdir + "app2/revision.sd").
                                    sd(selfdir + "app2/file.sd"))
    start
    feed(:file => selfdir + "admin.xml")
    feed(:file => selfdir + "admin_files.xml")
#    vespa.search["search"].first.stop
#    sleep 5
#    vespa.search["search"].first.start
#    sleep 5
    vespa.search["search"].first.trigger_flush
    feed(:file => selfdir + "admin.xml")
    assert_log_not_matches("vespa-proton-bin: filechunk.cpp:588:")
  end

  def test_proton_online_state
    @valgrind=false
    set_owner("geirst")
    set_description("Tests that online state is false until replay of transaction log is done")
    deploy_app(SearchApp.new.sd("#{selfdir}/banana.sd").flush_on_shutdown(false))
    start

    num_docs = 300000
    f = File.new("#{dirs.tmpdir}/#{SecureRandom.urlsafe_base64}_mixedfeed.xml", "w")
    generate_mixed_feed(f, 0, num_docs, num_docs, num_docs)
    f.close
    feed_and_wait_for_docs("banana", num_docs, :file => f.path)
    restart_search_node
    timeout = 120*5  # 120 seconds as sleep is 0.2s
    num_tries = 0
    num_state_verifications = 0
    prev_replay_progress = 0
    while true
      num_tries += 1
      proton_status = vespa.search["search"].first.get_proton_status
      state = vespa.search["search"].first.get_state
      num_state_verifications += 1
      hit_count = search("sddocname:banana").hitcount
      puts "Got #{hit_count} hits on try #{num_tries}"
      if hit_count == num_docs
        puts "Success on try #{num_tries}, #{num_state_verifications} state verifications"
        if (state.match(/\"online\", \"true\"/))
          break
        else
          puts "Wait for state indicating 'online' after query returning expected number of docs"
        end
      elsif state.match(/online/) && state.match(/onlineState/)
        puts "Verify that that the system is offline or online"
        if state.match(/\"online\", \"false\"/)
          assert_match(/\"online\", \"false\"/, state)
          assert_match(/\"onlineState\", \"onlineSoon\"/, state)
          assert_match(/\"onlineDocs\", \"(\d*)\"/, state)
        else
          assert_match(/\"online\", \"true\"/, state)
          assert_match(/\"onlineState\", \"online\"/, state)
          assert_match(/\"onlineDocs\", \"#{num_docs}\"/, state)
        end
        proton_status_match = proton_status.match(/DocumentDB replay transaction log on startup \((\d*)% done\)/)
        # We can also get 'DocumentDB initializing' in this case
        if (proton_status_match != nil)
          replay_progress = proton_status_match[1].to_i
          puts "replay_progress = #{replay_progress} prev_replay_progress = #{prev_replay_progress}"
          assert(replay_progress >= prev_replay_progress)
          prev_replay_progress = replay_progress
        end
      end
      if num_tries == timeout
        puts "No success after #{num_tries} tries"
        break
      end
      sleep 0.2
    end
    assert_hitcount("sddocname:banana", num_docs)
    assert(num_state_verifications > 0)
    assert_match(/\"online\", \"true\"/, state)
    assert_match(/\"onlineState\", \"online\"/, state)
    assert_match(/\"onlineDocs\", \"#{num_docs}\"/, state)
    # We are not certain that we fetched progress at the exact end at 100%, give it some slack.
    # If the system is sluggish we might be online on the first try, don't check replay progress then.
    # We might also be offline on the first try, and completely online on the second try, don't check replay progress then.
    puts "prev_replay_progress: #{prev_replay_progress}"
  end

  def restart_search_node
    search_node = vespa.search["search"].first
    puts "About to restart search node"
    search_node.stop
    search_node.start
    puts "Search node restarted"
  end
  
  def teardown
    stop
  end

end
