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
    add_bundle(selfdir + "MultiPointTester.java")
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new.
                             chain(Chain.new("default", "vespa").add(
                                 Searcher.new("com.yahoo.test.MultiPointTester")))).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"multipoint.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("multipoint", 3, :file => selfdir+"feed-mp.xml")
    # save_result("query=title:pizza", selfdir+"example/mp-all.json")
    assert_geo_result("query=title:pizza", selfdir+"example/mp-all.json")

    semicolon = "%3B"
    geo = "pos.ll=N37.4#{semicolon}W122.0"
    attr = "pos.attribute=latlong"
    add = geo + "&" + attr
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-1.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-1.json")

    geo = "pos.ll=N63.4#{semicolon}E10.4"
    attr = "pos.attribute=homell"
    add = geo + "&" + attr
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-2.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-2.json")

    geo = "pos.ll=N51.5#{semicolon}W0.0"
    attr = "pos.attribute=workll"
    add = geo + "&" + attr
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-3a.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-3a.json")

    geo = "pos.ll=N37.4#{semicolon}W122.0"
    attr = "pos.attribute=workll"
    add = geo + "&" + attr
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-3b.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-3b.json")

    geo = "pos.ll=N63.4#{semicolon}E10.4"
    attr = "pos.attribute=workll"
    add = geo + "&" + attr
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-3c.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-3c.json")

    geo = "pos.ll=N50.0#{semicolon}E20.0"
    attr = "pos.attribute=vacationll"
    add = geo + "&" + attr
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-4.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-4.json")

    geo = "pos.ll=N40.8#{semicolon}E14.2"
    attr = "pos.attribute=latlong"
    add = geo + "&" + attr
    # save_result("query=title:napoli&#{add}", selfdir+"example/mp-5.json")
    assert_geo_result("query=title:napoli&#{add}", selfdir+"example/mp-5.json")

    add = "multipointtester=true"
    # save_result("query=title:pizza&#{add}", selfdir+"example/mp-6.json")
    assert_geo_result("query=title:pizza&#{add}", selfdir+"example/mp-6.json")

    yqlpre = 'select * from multipoint'
    yqlgeo4 = 'geoLocation("latlong", 40.8, 14.25, "10 km")'
    yqlgeo2 = 'geoLocation("homell", 63.5, 10.5, "200 km")'
    yqlgeo3 = 'geoLocation("workll", 0.0, 0.0, "300 km")'
    yqlgeo1 = 'geoLocation("vacationll", -60.0, 120.0, "100 km")'

    yql = "#{yqlpre} where #{yqlgeo1} or #{yqlgeo2} or #{yqlgeo3} or #{yqlgeo4};"

    # save_result("yql=#{URI::encode(yql)}&tracelevel=1", selfdir+"example/mp-7.json")
    assert_geo_result("yql=#{URI::encode(yql)}&tracelevel=1", selfdir+"example/mp-7.json")
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
    #     save_result("query=title:pizza&#{geo}", selfdir+"example/foo.json")
    assert_geo_result("query=title:pizza&#{geo}", selfdir+"example/foo.json")

    badloc="location=(2,122163600,89998536,290112,4,2000,0,109704)"
    #     save_result("query=title:pizza&#{badloc}", selfdir+"empty.json")
    assert_geo_result("query=title:pizza&#{badloc}", selfdir+"empty.json")

    geo = "pos.bb=n=37.8,s=37.0,e=-122.0,w=-122.5"
    #     save_result("query=title:pizza&#{geo}", selfdir+"example/foo-bb.json")
    assert_geo_result("query=title:pizza&#{geo}", selfdir+"example/foo-bb.json")
  end

  def test_perf_zcurve
    @valgrind = false
    deploy_app(
      ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         component(AccessLog.new("disabled")).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("multitest").
                      sd(selfdir+"point.sd").
                      threads_per_search(1).
                      indexing("mycc")))
    start

    node = vespa.adminserver

    node.copy(selfdir + "gendata.c", dirs.tmpdir)

    tmp_bin_dir = node.create_tmp_bin_dir
    (exitcode, output) = execute(node, "set -x && cd #{dirs.tmpdir} && cc gendata.c -o #{tmp_bin_dir}/a.out && time #{tmp_bin_dir}/a.out")
    puts "compile output: #{output}"

    (exitcode, output) = execute(node, "time vespa-feeder #{dirs.tmpdir}/feed-2.xml")
    puts "feeder output: #{output}"

    wait_for_hitcount("sddocname:point", 1234567, 30)

    # save_result("query=title:foo", selfdir+"big/bigresult.foo.json")
    # save_result("query=title:bar", selfdir+"big/bigresult.bar.json")

    assert_geo_result("query=title:foo", selfdir+"big/bigresult.foo.json")
    assert_geo_result("query=title:bar", selfdir+"big/bigresult.bar.json")

    semicolon = "%3B"
    geo = "pos.ll=N37.416383#{semicolon}W122.024683&pos.radius=500km"

    # save_result("query=title:foo&#{geo}", selfdir+"big/bigresult.foo-geo.json")
    # save_result("query=title:bar&#{geo}", selfdir+"big/bigresult.bar-geo.json")

    assert_geo_result("query=title:foo&#{geo}", selfdir+"big/bigresult.foo-geo.json")
    assert_geo_result("query=title:bar&#{geo}", selfdir+"big/bigresult.bar-geo.json")

    large_dist_p95 = run_fbench(vespa.adminserver, "#{dirs.tmpdir}/urls-2.txt")
    small_dist_p95 = run_fbench(vespa.adminserver, "#{dirs.tmpdir}/urls-3.txt")

    puts "Want 95% at small distances (#{small_dist_p95}) much less than at large distances (#{large_dist_p95})"
    assert(small_dist_p95 * 3 < large_dist_p95)
  end

  def run_fbench(qrserver, queries)
    fbench = Perf::Fbench.new(qrserver, qrserver.name, Environment.instance.vespa_web_service_port)
    fbench.runtime = 100
    fbench.clients = 1
    fbench.disable_tls = false
    fbench.query(queries)
    p95 = fbench.p95.to_f
    puts "vespa-fbench reports 95th percentile: #{p95} ms"
    assert(p95 < 500.00)
    p95
  end

  def assert_geo_result(query, result_file)
    r = search(query)
    puts "XML: #{r.xmldata}"
    assert_result_with_timeout(2, query, result_file)
  end

  def teardown
    stop
  end

end
