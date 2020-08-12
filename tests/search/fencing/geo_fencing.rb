# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_test'
require 'app_generator/container_app'
require 'app_generator/search_app'
require 'environment'

class GeoFencingTest < SearchTest

  def setup
    set_owner("arnej")
    set_description("example of geo fencing feature")
  end

  def timeout_seconds
    3600
  end

def test_with_geo_fencing
    deploy_app(
        ContainerApp.new.
               container(
                         Container.new("mycc").
                         search(Searching.new).
                         docproc(DocumentProcessing.new)).
               search(SearchCluster.new("fencing").
                      sd(selfdir+"withfence.sd").
                      indexing("mycc")))
    start
    feed_and_wait_for_docs("withfence", 6, :file => selfdir+"docs.json")
    # save_result("query=title:pizza", selfdir+"out-all.xml")
    assert_result("query=title:pizza", selfdir+"out-all.xml")

    crank = '&ranking=center'
    mrank = '&ranking=maybe'
    wrank = '&ranking=withraw'
    yrank = '&ranking=foryql'

    cattr = "&pos.attribute=center"
    mattr = "&pos.attribute=maybecenter"

    noradius = '&pos.radius=-1'

    qrytxt = 'query=title:pizza'

    yqlpre = 'select * from fencing'
    yqltxt = 'title contains "pizza"'
    yqllbl = '[{"label":"foobar"}]'

    semicolon = "%3B"
    # 1c) Near two docs: California, USA
    geo = "&pos.ll=N37.4#{semicolon}W122.0"
    add = geo + cattr + noradius + crank
    # save_result(qrytxt + add, selfdir+"out-1.xml")
    assert_result(qrytxt + add, selfdir+"out-1.xml")

    # 1m)
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-1m.xml")
    assert_result(qrytxt + add, selfdir+"out-1.xml")


    # Same as 1c, with YQL:
    yqlgeo = 'geoLocation("center", 37.4, -122.0, "-1m")'
    yql = URI::encode("#{yqlpre} where #{yqltxt} and (#{yqllbl} #{yqlgeo});")
    qry = "yql=" + yql + crank
    # save_result(qry, selfdir+"out-1.xml")
    assert_result(qry, selfdir+"out-1.xml")

    qry = "yql=" + yql + wrank
    # save_result(qry, selfdir+"out-1cw-yql.xml")
    assert_result(qry, selfdir+"out-1cw-yql.xml")

    # Same as 1m, with YQL:
    yqlgeo = 'geoLocation("maybecenter", 37.4, -122.0, "-1m")'
    yql = URI::encode("#{yqlpre} where rank(#{yqltxt},#{yqllbl} #{yqlgeo});")
    qry = "yql=" + yql + mrank
    # save_result(qry, selfdir+"out-1m-yql.xml")
    assert_result(qry, selfdir+"out-1.xml")

    # 1y)
    qry = "yql=" + yql + yrank
    # save_result(qry, selfdir+"out-1y.xml")
    assert_result(qry, selfdir+"out-1y.xml")

    # 1w)
    qry = "yql=" + yql + wrank
    # save_result(qry, selfdir+"out-1mw-yql.xml")
    assert_result(qry, selfdir+"out-1y.xml")

    # 2c) Near one doc: Trondheim, Norway
    geo = "&pos.ll=N63.4#{semicolon}E10.4"
    add = geo + cattr + noradius + crank
    # save_result(qrytxt + add, selfdir+"out-2.xml")
    assert_result(qrytxt + add, selfdir+"out-2.xml")

    # 2m)
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-2m.xml")
    assert_result(qrytxt + add, selfdir+"out-2.xml")

    # 3c) Far from all docs: Sydney, Australia
    geo = "&pos.ll=S33.8#{semicolon}E151.2"
    add = geo + cattr + noradius + crank
    # save_result(qrytxt + add, selfdir+"out-3.xml")
    assert_result(qrytxt + add, selfdir+"out-3.xml")

    # 3m)
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-3m.xml")
    assert_result(qrytxt + add, selfdir+"out-3.xml")

    # 3w)
    add = geo + mattr + noradius + wrank
    # save_result(qrytxt + add, selfdir+"out-3y.xml")
    assert_result(qrytxt + add, selfdir+"out-3y.xml")

    # 3y) YQL and label:
    yqlgeo = 'geoLocation("maybecenter", -33.8, 151.2, "-1m")'
    yql = URI::encode("#{yqlpre} where rank(#{yqltxt},#{yqllbl} #{yqlgeo});")
    qry = "yql=" + yql + yrank
    # save_result(qry, selfdir+"out-3y.xml")
    assert_result(qry, selfdir+"out-3y.xml")

    # 4) Westminster: "N51.513912;W0.128381"
    geo = "&pos.ll=N51.5#{semicolon}W0.1"
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-4.xml")
    assert_result(qrytxt + add, selfdir+"out-4.xml")

    # 5) Krakow: "N50.061598;E19.937473"
    geo = "&pos.ll=N50.1#{semicolon}E19.9"
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-5.xml")
    assert_result(qrytxt + add, selfdir+"out-5.xml")

    # More complex YQL:
    yqlgeo1 = 'geoLocation("maybecenter", 40.8, 14.25, "150 km")'
    yqlgeo2 = 'geoLocation("center", 63.5, 10.5, "200 km")'
    yqlgeo3 = 'geoLocation("center", 0.0, 0.0, "3 km")'
    yqlgeo4 = 'geoLocation("maybecenter", -60.0, 120.0, "1000 km")'

    yql = "#{yqlpre} where #{yqlgeo1} or #{yqlgeo2} or #{yqlgeo3} or #{yqlgeo4};"
    qry = 'yql=' + URI::encode(yql) + crank

    # save_result(qry, selfdir+"out-mp-yql.xml")
    assert_result(qry, selfdir+"out-mp-yql.xml")
  end

  def teardown
    stop
  end

end
