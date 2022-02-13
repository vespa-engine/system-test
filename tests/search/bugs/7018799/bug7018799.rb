# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'
require 'app_generator/container_app'
require 'environment'

class RecoveryLosesAnnotations < SearchTest

  def setup
    set_owner("arnej")
  end

  def qf(fieldname, word)
    return "query=#{fieldname}:#{word}"
  end

  def ff(fieldname, word)
    return dirs.tmpdir + fieldname + "-" + word + ".xml"
  end

  def save(fn, wd)
    q = qf(fn, wd)
    f = ff(fn, wd)
    puts "save result of '#{q}' in '#{f}'"
    save_result_with_timeout(5, q, f)
  end

  def check(fn, wd)
    q = qf(fn, wd)
    f = ff(fn, wd)
    puts "check result of '#{q}' in '#{f}'"
    assert_result_with_timeout(5, q, f)
  end

  def saveAll
    save("title", "foo")
    save("title", "bar")
    save("onlyidx", "foo")
    save("onlyidx", "bar")
    save("onlyattr", "foo")
    save("onlyattr", "bar")
    save("both", "foo")
    save("both", "bar")
    save("source", "Dr.eye")
  end

  def checkAll
    check("title", "bar")
    check("title", "foo")
    check("onlyattr", "bar")
    check("onlyattr", "foo")
    check("onlyidx", "bar")
    check("onlyidx", "foo")
    check("both", "bar")
    check("both", "foo")
    check("source", "Dr.eye")
  end

  def wait_for_online_on(docs, node, nodeid)
    c = -1
    rx = /"onlineDocs", "(\d+)"/
    snid = "multitest/search/cluster.multitest/#{nodeid}/realtimecontroller"
    trycnt = 0
    while (c != docs) && (trycnt < 180)
      trycnt += 1
      sleep 1
      op = node.execute("vespa-proton-cmd --id=#{snid} getState", :exceptiononfailure => false)
      #puts "GOT op: #{op}"
      m = rx.match(op)
      if m
        #puts "got match: #{m}"
        c = m[1].to_i
      else
        puts "no match: #{m} for #{op}"
        c = -1
      end
      #puts "got c: #{c}"
    end
    assert_equal(docs, c)
  end

  def test_bug7018799
    deploy_app(
        ContainerApp.new.
               container(Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      num_parts(2).redundancy(2).ready_copies(1).
                      sd(selfdir+"rla.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("rla", 3, :file => selfdir+"feed.xml")
    saveAll

    sn0 = vespa.search["multitest"].searchnode[0]
    sn1 = vespa.search["multitest"].searchnode[1]

    sn0.stop
    feed_and_wait_for_docs("rla", 4, :file => selfdir+"xtra1.xml")
    checkAll
    sn0.execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.multitest/n0")
    checkAll

    sn0.start
    wait_for_online_on(2, sn0, 0)
    wait_for_hitcount("sddocname:rla", 4)
    checkAll
    feed_and_wait_for_docs("rla", 5, :file => selfdir+"xtra2.xml")
    checkAll
    checkAll

    sn1.stop
    wait_for_online_on(5, sn0, 0)
    checkAll
    feed_and_wait_for_docs("rla", 6, :file => selfdir+"xtra3.xml")
    checkAll
  end

  def teardown
    stop
  end

end
