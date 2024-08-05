# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'
require 'app_generator/container_app'
require 'environment'

class RecoveryLosesAnnotations < IndexedOnlySearchTest
  def setup
    set_owner("arnej")
    @sps = [ "0/0", "1/0" ]
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

  def wait_for_docs_on(docs, nodeid)
    sp = @sps[nodeid]
    wait_for_hitcount("sddocname:rla&nocache&model.searchPath=#{sp}", docs, 120)
  end

  def test_bug7018799
    deploy_app(
      SearchApp.new.
        cluster_name("multitest").
        num_parts(2).redundancy(2).ready_copies(1).
        sd(selfdir+"rla.sd"))
    start
    feed_and_wait_for_docs("rla", 3, :file => selfdir+"feed.json")
    saveAll

    sn0 = vespa.search["multitest"].searchnode[0]
    sn1 = vespa.search["multitest"].searchnode[1]

    sn0.stop
    feed_and_wait_for_docs("rla", 4, :file => selfdir+"xtra1.json")
    checkAll
    sn0.execute("rm -rf #{Environment.instance.vespa_home}/var/db/vespa/search/cluster.multitest/n0")
    checkAll

    sn0.start
    wait_for_docs_on(2, 0)
    wait_for_docs_on(2, 1)
    checkAll
    feed_and_wait_for_docs("rla", 5, :file => selfdir+"xtra2.json")
    checkAll
    checkAll

    sn1.stop
    wait_for_docs_on(5, 0)
    wait_for_docs_on(0, 1)
    checkAll
    feed_and_wait_for_docs("rla", 6, :file => selfdir+"xtra3.json")
    checkAll
  end

  def teardown
    stop
  end

end
