# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'persistent_provider_test'
require 'set'
require 'environment'
require 'securerandom'

class VisitDynamicDistributionTest < PersistentProviderTest

  def setup
    @numdocs = 500
    @valgrind = false
    # TODO: change name away from "lock", since they're really not
    @ackFile = "#{Environment.instance.vespa_home}/tmp/ack.lock"
    @killFile = "#{Environment.instance.vespa_home}/tmp/kill.lock"
    @targetDir = "#{Environment.instance.vespa_home}/tmp/vespa-visit"
    @progressFile = "#{Environment.instance.vespa_home}/tmp/progress_dynamic"
    set_owner("vekterli")

    @feed_file = "#{SecureRandom::urlsafe_base64}_tmpfeed_visitdynamic.xml"
    make_feed_file(@feed_file, "music", 0, 4, 100)
    set_expected_logged(/pidfile/)

    deploy_app(default_app.
               redundancy(1).
               num_nodes(1).
               distribution_bits(14).
               bucket_split_count(15))

    start
  end

  def teardown
    begin
      if File.exist?(@feed_file)
        File.delete(@feed_file)
      end
      # A bit dirty to do this here since the files/dirs weren't created during setup
      vespa.storage["storage"].storage["0"].execute("rm -f #{@ackFile}")
      vespa.storage["storage"].storage["0"].execute("rm -f #{@killFile}")
      vespa.storage["storage"].storage["0"].execute("rm -rf #{@targetDir}")
      vespa.storage["storage"].storage["0"].execute("rm -f #{@progressFile}*")
      vespa.storage["storage"].storage["0"].execute("pkill -KILL -f vespa-visit",
                                 :exceptiononfailure => false)
    ensure
      stop
    end
  end

  def fancyPuts(s)
    lineStr = ("-" * 35) + "\n"
    puts lineStr + s + "\n" +  lineStr
  end

  def test_visit_with_concurrent_cluster_resize
    # Create pseudo-IPC files with which we can signal the visiting target to continue or die
    vespa.storage["storage"].storage["0"].execute("touch #{@ackFile}")
    vespa.storage["storage"].storage["0"].execute("touch #{@killFile}")
    # Compile java code
    puts "Compiling visitor handler"
    vespa.storage["storage"].storage["0"].execute("mkdir -p #{@targetDir}/src")
    vespa.storage["storage"].storage["0"].execute("mkdir -p #{@targetDir}/classes")
    vespa.storage["storage"].storage["0"].copy(selfdir + "java", "#{@targetDir}/src")
    vespa.storage["storage"].storage["0"].execute("javac -cp #{Environment.instance.vespa_home}/lib/jars/vespaclient-java-jar-with-dependencies.jar " +
                               "-d #{@targetDir}/classes " +
                               "#{@targetDir}/src/com/yahoo/vespaclient/test/TestVisitorHandler.java")

    feedfile(@feed_file)

    puts "Letting storage catch up with bucket splitting"
    rounds = 10
    while rounds > 0 do
      docCheck = vespa.storage["storage"].storage["0"].execute("vespa-visit -i 2>&1 | grep 'id:music' | wc -l")
      if docCheck.strip.to_i == @numdocs
        break
      end
      sleep 2
      rounds -= 1
    end
    assert(rounds > 0)

    visit_cluster_during_redeploy(2, 2, 15)
    # FIXME: commented out until bug is fixed where graceful storage shutdown does
    # not send replies to all active requests
    #
    #visit_cluster_during_redeploy(1, 1, 14)
  end

  def visit_cluster_during_redeploy(targetDist, targetStorage, targetBits)
    ackTime = vespa.storage["storage"].storage["0"].execute("stat -c '%Y' #{@ackFile}").strip.to_i

    puts "Setting up asynchronous visiting target in own thread"
    ret = Hash.new
    # Start vespa-visit-target with custom handler
    targetThread = Thread.new(ret){
        ret["target"] = vespa.storage["storage"].storage["0"].execute("CLASSPATH=#{@targetDir}/classes vespa-visit-target -s client/0 " +
                                                   "--visithandler com.yahoo.vespaclient.test.TestVisitorHandler " +
                                                   "--visitoptions \"--threshold 100 --ackfile #{@ackFile} " +
                                                   "--killfile #{@killFile}\" 2>&1 | grep 'id:music'").split("\n")
        puts "Target complete"
    }
    # If this fails it's presumably because vespa-visit-target failed to start
    assert targetThread.alive?

    puts "Beginning visiting in own thread"
    visitThread = Thread.new(ret){
      ret["visit"] = vespa.storage["storage"].storage["0"].execute("vespa-visit -i -m 1 -d client/0/visit-destination 2>&1 | " +
                                                "egrep -v 'NO_ADDRESS_FOR_SERVICE|HANDSHAKE_FAILED|UNKNOWN_SESSION|ABORTED'",
                                                :exceptiononfailure => false)
      puts "Visiting complete"
    }

    sleep 1

    puts("Waiting for visiting target to receive at least 100 " +
         "docs, at which point it will pause")
    while vespa.storage["storage"].storage["0"].execute("stat -c '%Y' #{@ackFile}").strip.to_i == ackTime
      sleep 2
    end

    puts "OK. Deploying #{targetDist}x#{targetStorage} config for #{targetBits} distribution bits"
    assert visitThread.alive?
    assert targetThread.alive?

    vespa.stop_base # To avoid port conflicts when new services are started

    deploy_app(default_app.
               redundancy(targetDist).
               num_nodes(targetDist).
               distribution_bits(targetBits).
               bucket_split_count(15).
               validation_override("redundancy-increase"))

    vespa.start_base

    # Quite a bit of timeout since bit count update happens at 5
    # minute intervals
    vespa.storage["storage"].wait_for_distribution_bits(targetBits, 400)
    vespa.storage["storage"].wait_for_node_count("distributor", targetDist, "u", 400)
    vespa.storage["storage"].wait_for_node_count("storage", targetStorage, "u", 400)

    vespa.storage["storage"].wait_until_ready
    assert visitThread.alive?
    assert targetThread.alive?
    vespa.storage["storage"].storage["0"].execute("touch #{@ackFile}")

    puts "Waiting for client thread to finish"
    visitThread.join
    puts "Visiting client thread finished"

    puts "Telling visitor target that it's OK to terminate"
    vespa.storage["storage"].storage["0"].execute("touch #{@killFile}")
    targetThread.join
    puts "Visiting target thread finished"

    puts "Verifying correct document IDs (duplicates are allowed)"
    docData = get_user_doc_set(ret["target"])

    checkSet = Set.new
    (0...5).each do |user|
      (0...100).each { |doc| checkSet.add(doc_id_str(user, doc)) }
    end

    if docData[0].length != 500
      puts "FAILED! Dumping missing documents"
      missing = checkSet - docData[0]
      missing.each { |doc| puts(doc.to_s) }
    end
    assert_equal(500, docData[0].length) # early out-assertion

    # temp debugging code
    #File.open('test/docs', 'w') do |f|
    #  docData[0].each { |doc| f.puts(doc.to_s) }
    #end

    assert_equal(Set.new, docData[0] - checkSet)
    puts "All documents retrieved OK. There were " + docData[1].to_s + " duplicates"
  end

  def doc_id_str(user, doc)
    "n=#{user}:#{doc}"
  end

  # Get a pair <doc id set, duplicate count> for the given list of document strings
  def get_user_doc_set(docs)
    docSet = Set.new
    duplicates = 0
    docs.each do |d|
      splitStr = d.split(":")
      x = docSet.add?(splitStr[3] + ':' + splitStr[4])
      if x == nil
        duplicates += 1
      end
    end
    return [docSet, duplicates]
  end

  def verify_all_docs_present(doc_set)
    check_set = Set.new
    (0...5).each do |user|
      (0...100).each { |doc| check_set.add(doc_id_str(user, doc)) }
    end
    assert_equal(Set.new, doc_set - check_set)
  end

  def visit_and_deploy(targetDist, targetStorage, targetBits, distBlocklist)
    puts "Verifying document count"
    vespa.storage["storge"].assert_document_count(@numdocs)

    vespa.storage["storage"].storage["0"].execute("rm -f #{@progressFile}*")
    puts "Fetching >= 150 documents with current distribution bit count"
    docsOld = vespa.storage["storage"].storage["0"].execute("vespa-visit -i --maxtotalhits 150 -p " +
                                         "#{@progressFile}"
                                         ).split("\n").select { |d| d =~ /id:music/ }
    vespa.storage["storage"].storage["0"].execute("cat #{@progressFile}");

    puts "Redeploying with #{targetBits} distribution bit(s)"
    vespa.stop_base

    deploy_app(default_app.
               redundancy(targetDist).
               num_nodes(targetDist).
               distribution_bits(targetBits).
               bucket_split_count(15).
               validation_override("redundancy-increase"))

    vespa.start_base

    # Quite a bit of timeout since bit count update happens at 5
    # minute intervals
    vespa.storage["storage"].wait_for_distribution_bits(targetBits, 400)
    vespa.storage["storage"].wait_for_node_count("distributor", targetDist, "u", 400)
    vespa.storage["storage"].wait_for_node_count("storage", targetStorage, "u", 400)

    vespa.storage["storage"].wait_until_ready(30, distBlocklist)

    puts "Continuing visiting with new distribution bit count"
    vespa.storage["storage"].storage["0"].execute("cat #{@progressFile}");
    docsNew = vespa.storage["storage"].storage["0"].execute("vespa-visit -i -p #{@progressFile}"
                                         ).split("\n").select { |d| d =~ /id:music/ }
    #puts "old: " + docsOld.length.to_s
    #puts "new: " + docsNew.length.to_s
    #assert_equal(docsNew.length, @numdocs - docsOld.length)

    puts "Verifying correct document IDs"
    #docSet = Set.new
    docsOldData = get_user_doc_set(docsOld)
    docsNewData = get_user_doc_set(docsNew)
    # Should have no duplicate results within each visiting
    assert_equal(0, docsOldData[1])
    assert_equal(0, docsNewData[1])
    docSet = docsOldData[0] + docsNewData[0];
    assert_equal(500, docSet.length) # early out-assertion
    # But there may be duplicates between the two
    verify_all_docs_present(docSet)
    puts "All documents retrieved OK"
  end

  def test_visit_with_progress
    feedfile(@feed_file)

    visit_and_deploy(2, 2, 15, [])
    # Now that we've tested going from low->hi, try it the other way around
    # Current deployment is already 2x2
    vespa.storage["storage"].storage["0"].execute("rm #{@progressFile}")
    visit_and_deploy(1, 1, 14, ["1"]) # Don't try to sync against distributor 1
  end

end
