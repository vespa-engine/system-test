# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'environment'

class FastGeoSearchTest < SearchTest

  def setup
    set_owner("arnej")
    set_description("perform geo search speed test")
  end

  def timeout_seconds
    3600
  end

def test_multiple_position_fields
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"multipoint.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("multipoint", 2, :file => selfdir+"feed-mp.xml")
    #     save_result("query=title:pizza", selfdir+"example/mp-all.xml")
    assert_result("query=title:pizza", selfdir+"example/mp-all.xml")

    semicolon = "%3B"
    geo = "pos.ll=N37.4#{semicolon}W122.0"
    attr = "pos.attribute=latlong"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"example/mp-1.xml")
    assert_result("query=title:pizza&#{add}", selfdir+"example/mp-1.xml")

    geo = "pos.ll=N63.4#{semicolon}E10.4"
    attr = "pos.attribute=homell"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"example/mp-2.xml")
    assert_result("query=title:pizza&#{add}", selfdir+"example/mp-2.xml")

    geo = "pos.ll=N51.5#{semicolon}W0.0"
    attr = "pos.attribute=workll"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"example/mp-3a.xml")
    assert_result("query=title:pizza&#{add}", selfdir+"example/mp-3a.xml")

    geo = "pos.ll=N37.4#{semicolon}W122.0"
    attr = "pos.attribute=workll"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"example/mp-3b.xml")
    assert_result("query=title:pizza&#{add}", selfdir+"example/mp-3b.xml")

    geo = "pos.ll=N63.4#{semicolon}E10.4"
    attr = "pos.attribute=workll"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"example/mp-3c.xml")
    assert_result("query=title:pizza&#{add}", selfdir+"example/mp-3c.xml")

    geo = "pos.ll=N50.0#{semicolon}E20.0"
    attr = "pos.attribute=vacationll"
    add = geo + "&" + attr
    #     save_result("query=title:pizza&#{add}", selfdir+"example/mp-4.xml")
    assert_result("query=title:pizza&#{add}", selfdir+"example/mp-4.xml")
  end

  def test_sunnyvale_pizza
    # this is straight from the documentation
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"point.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("point", 1, :file => selfdir+"feed-0.xml")
    semicolon = "%3B"
    geo = "pos.ll=N37.416383#{semicolon}W122.024683"
    #     save_result("query=title:pizza&#{geo}", selfdir+"example/foo.xml")
    assert_result("query=title:pizza&#{geo}", selfdir+"example/foo.xml")

    badloc="location=(2,122163600,89998536,290112,4,2000,0,109704)"
    #     save_result("query=title:pizza&#{badloc}", selfdir+"empty.xml")
    assert_result("query=title:pizza&#{badloc}", selfdir+"empty.xml")

    geo = "pos.bb=n=37.8,s=37.0,e=-122.0,w=-122.5"
    #     save_result("query=title:pizza&#{geo}", selfdir+"example/foo-bb.xml")
    assert_result("query=title:pizza&#{geo}", selfdir+"example/foo-bb.xml")
  end

  def test_perf_zcurve
    @valgrind = false
    deploy_app(
      ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"point.sd").
                      threads_per_search(1).
                      indexing("mycc")))
    start

    node = vespa.adminserver

    node.copy(selfdir + "gendata.c", dirs.tmpdir)

    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && cc gendata.c && time ./a.out")
    puts "compile output: #{output}"

    (exitcode, output) = execute(node, "time vespa-feeder #{dirs.tmpdir}/feed-2.xml")
    puts "feeder output: #{output}"

    wait_for_hitcount("sddocname:point", 1234567, 30)

    # save_result("query=title:foo", selfdir+"big/bigresult.foo.xml")
    # save_result("query=title:bar", selfdir+"big/bigresult.bar.xml")

    assert_result("query=title:foo", selfdir+"big/bigresult.foo.xml")
    assert_result("query=title:bar", selfdir+"big/bigresult.bar.xml")

    semicolon = "%3B"
    geo = "pos.ll=N37.416383#{semicolon}W122.024683&pos.radius=500km"

    # save_result("query=title:foo&#{geo}", selfdir+"big/bigresult.foo-geo.xml")
    # save_result("query=title:bar&#{geo}", selfdir+"big/bigresult.bar-geo.xml")

    assert_result("query=title:foo&#{geo}", selfdir+"big/bigresult.foo-geo.xml")
    assert_result("query=title:bar&#{geo}", selfdir+"big/bigresult.bar-geo.xml")

    large_dist_p95 = run_fbench(vespa.adminserver, "#{dirs.tmpdir}/urls-2.txt")
    small_dist_p95 = run_fbench(vespa.adminserver, "#{dirs.tmpdir}/urls-3.txt")

    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && fbench -n 1 -c 0 -q urls-3.txt localhost #{Environment.instance.vespa_web_service_port}")
    puts "vespa-fbench output: #{output}"

    puts "Want 95% at small distances (#{small_dist_p95}) much less than at large distances (#{large_dist_p95})"
    assert(small_dist_p95 * 3 < large_dist_p95)
  end

  def run_fbench(qrserver, queries)
    fbench = Perf::Fbench.new(qrserver, qrserver.name, Environment.instance.vespa_web_service_port)
    fbench.runtime = 100
    fbench.clients = 1
    fbench.query(queries)
    p95 = fbench.p95.to_f
    puts "vespa-fbench reports 95th percentile: #{p95} ms"
    assert(p95 < 500.00)
    p95
  end

  def teardown
    stop
  end

end
