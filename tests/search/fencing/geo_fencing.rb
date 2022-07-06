# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

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
    # save_result("query=title:pizza", selfdir+"out-all.json")
    assert_result("query=title:pizza", selfdir+"out-all.json")

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
    yqllbl = '{label:"foobar"}'

    semicolon = "%3B"
    # 1c) Near two docs: California, USA
    geo = "&pos.ll=N37.4#{semicolon}W122.0"
    add = geo + cattr + noradius + crank
    # save_result(qrytxt + add, selfdir+"out-1.json")
    assert_result(qrytxt + add, selfdir+"out-1.json")

    # 1m)
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-1m.xml")
    assert_result(qrytxt + add, selfdir+"out-1.json")


    # Same as 1c, with YQL:
    yqlgeo = 'geoLocation("center", 37.4, -122.0, "-1m")'
    yql = CGI::escape("#{yqlpre} where #{yqltxt} and (#{yqllbl} #{yqlgeo})")
    qry = "yql=" + yql + crank
    # save_result(qry, selfdir+"out-1.json")
    assert_result(qry, selfdir+"out-1.json")

    qry = "yql=" + yql + wrank
    # save_result(qry, selfdir+"out-1cw-yql.json")
    assert_result(qry, selfdir+"out-1cw-yql.json")

    # Same as 1m, with YQL:
    yqlgeo = 'geoLocation("maybecenter", 37.4, -122.0, "-1m")'
    yql = CGI::escape("#{yqlpre} where rank(#{yqltxt},#{yqllbl} #{yqlgeo});")
    qry = "yql=" + yql + mrank
    # save_result(qry, selfdir+"out-1m-yql.xml")
    assert_result(qry, selfdir+"out-1.json")

    # 1y)
    qry = "yql=" + yql + yrank
    # save_result(qry, selfdir+"out-1y.json")
    assert_result(qry, selfdir+"out-1y.json")

    # 1w)
    qry = "yql=" + yql + wrank
    # save_result(qry, selfdir+"out-1mw-yql.xml")
    assert_result(qry, selfdir+"out-1y.json")

    # 2c) Near one doc: Trondheim, Norway
    geo = "&pos.ll=N63.4#{semicolon}E10.4"
    add = geo + cattr + noradius + crank
    # save_result(qrytxt + add, selfdir+"out-2.json")
    assert_result(qrytxt + add, selfdir+"out-2.json")

    # 2m)
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-2m.xml")
    assert_result(qrytxt + add, selfdir+"out-2.json")

    # 3c) Far from all docs: Sydney, Australia
    geo = "&pos.ll=S33.8#{semicolon}E151.2"
    add = geo + cattr + noradius + crank
    # save_result(qrytxt + add, selfdir+"out-3.json")
    assert_result(qrytxt + add, selfdir+"out-3.json")

    # 3m)
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-3m.xml")
    assert_result(qrytxt + add, selfdir+"out-3.json")

    # 3w)
    add = geo + mattr + noradius + wrank
    # save_result(qrytxt + add, selfdir+"out-3y.json")
    assert_result(qrytxt + add, selfdir+"out-3y.json")

    # 3y) YQL and label:
    yqlgeo = 'geoLocation("maybecenter", -33.8, 151.2, "-1m")'
    yql = CGI::escape("#{yqlpre} where rank(#{yqltxt},#{yqllbl} #{yqlgeo});")
    qry = "yql=" + yql + yrank
    # save_result(qry, selfdir+"out-3y.json")
    assert_result(qry, selfdir+"out-3y.json")

    # 4) Westminster: "N51.513912;W0.128381"
    geo = "&pos.ll=N51.5#{semicolon}W0.1"
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-4.json")
    assert_result(qrytxt + add, selfdir+"out-4.json")

    # 5) Krakow: "N50.061598;E19.937473"
    geo = "&pos.ll=N50.1#{semicolon}E19.9"
    add = geo + mattr + noradius + mrank
    # save_result(qrytxt + add, selfdir+"out-5.json")
    assert_result(qrytxt + add, selfdir+"out-5.json")

    # More complex YQL:
    yqlgeo1 = 'geoLocation("maybecenter", 40.8, 14.25, "150 km")'
    yqlgeo2 = 'geoLocation("center", 63.5, 10.5, "200 km")'
    yqlgeo3 = 'geoLocation("center", 0.0, 0.0, "3 km")'
    yqlgeo4 = 'geoLocation("maybecenter", -60.0, 120.0, "1000 km")'

    yql = "#{yqlpre} where #{yqlgeo1} or #{yqlgeo2} or #{yqlgeo3} or #{yqlgeo4};"
    qry = 'yql=' + CGI::escape(yql) + crank

    # save_result(qry, selfdir+"out-mp-yql.json")
    assert_result(qry, selfdir+"out-mp-yql.json")
  end

  def teardown
    stop
  end

end
