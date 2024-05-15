# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class RemoveByDate < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
  end

  def timeout_seconds
    1200
  end

  def postdeploy_wait(deploy_output)
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))
  end

  def redeploy(selection)
    deploy_output = super(generateapp(selection))
    postdeploy_wait(deploy_output)
  end

  def current_time
    node = vespa.search["search"].first
    node.get_current_time_as_int
  end

  def test_remove_by_date
    deploy_app(generateapp())
    start
    vespa.adminserver.logctl("searchnode:proton.server.documentremovetask", "debug=on")

    initial_age = 180
    puts "initial_age : #{initial_age}"
    future = current_time + initial_age
    doc_count = 6
    age_step = initial_age / doc_count
    testfeed = generatefeed(doc_count, future, age_step)
    feed_until_correct_output(testfeed, doc_count, 0, 0)

    wait_for_hitcount("sddocname:newsarticle", doc_count)
    redeploy("newsarticle.pubdate > now()")
    # To make sure that old documents don't go in at all
    testfeed2 = generatefeed(10, 10, age_step)
    feed_until_correct_output(testfeed2, 0, 10, 0)

    #feed some updates as well
    testupdates = generateupdates(doc_count)
    feed_until_correct_output(testupdates, doc_count, 0, 0)

    # Should still be having doc_count docs.
    diff = future - current_time
    puts "Diff before waiting: #{diff}"
    wait_for_hitcount("sddocname:newsarticle", doc_count, initial_age) if diff > 0
    diff = [future - current_time, 0].max
    puts "Diff after waiting: #{diff}. About to sleep"
    sleep(diff)
    cnt = wait_for_not_hitcount("sddocname:newsarticle", doc_count, initial_age)
    wait_for_hitcount("sddocname:newsarticle", cnt - 2, 360)
    wait_for_hitcount("sddocname:newsarticle", cnt - 4, 360)
    wait_for_hitcount("sddocname:newsarticle", 0, 360)
  end

  def generateapp(selection=nil)
    cluster = SearchCluster.new.sd(selfdir+"newsarticle.sd").garbagecollection(true).garbagecollectioninterval(2)
    if selection then
      cluster.doc_type("newsarticle", selection)
    end
    return SearchApp.new.cluster(cluster)
  end

  def generatefeed(numdocs, startage, agestep)
    feed = ""
    age = startage
    for i in 1..numdocs
      docid = "id:test:newsarticle::http://foo.bar.com/#{i}"
      title = "foo#{i}"
      pubdate = "#{age}"

      feed += "<document documenttype=\"newsarticle\" documentid=\"#{docid}\">\n"
      feed += "    <title>#{title}</title>\n"
      feed += "    <pubdate>#{pubdate}</pubdate>\n"
      feed += "</document>\n"

      age = age + agestep
    end
    return feed
  end

  def feed_until_correct_output(feed, expected_ok, expected_ignored, expected_failed, timeout=240)
    now = Time.now
    done = false
    while !done and Time.now < (now + timeout) do
      feedoutput = feedbuffer(feed, :exceptiononfailure => false)
      check_ok = check_correct_output(["ok: #{expected_ok}"], feedoutput)
      check_ignored = check_correct_output(["ignored: #{expected_ignored}"], feedoutput)
      check_failed = check_correct_output(["failed: #{expected_failed}"], feedoutput)
      done = check_ok and check_ignored and check_failed
      sleep 1
    end
    assert(done, "Did not get expected output ok(#{expected_ok}), ignored(#{expected_ignored}), failed(#{expected_failed})")
  end

  def generateupdates(numdocs)
    feed = ""
    for i in 1..numdocs
      docid = "id:test:newsarticle::http://foo.bar.com/#{i}"
      title = "updated#{i}"

      feed += "<update documenttype=\"newsarticle\" documentid=\"#{docid}\">\n"
      feed += "    <assign field=\"title\">#{title}</assign>\n"
      feed += "</update>\n"
    end
    return feed
  end

  def teardown
    stop
  end

end
