# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_search_test'

class SummaryFeatures < IndexedSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_summaryfeatures
    deploy_app(SearchApp.new.sd(selfdir + "sd2/test.sd"))
    start
    feed(:file => selfdir + "doc.xml")
    assert_summaryfeatures
  end

  def test_summaryfeatures_reload_config
    deploy_app(SearchApp.new.sd(selfdir + "sd1/test.sd"))
    start
    feed_and_wait_for_docs("test", 6, :file => selfdir + "doc.xml")

    # Change to sd containing summaryfeatures, reload config, but no reindexing
    deploy_app(SearchApp.new.sd(selfdir + "sd2/test.sd"))

    # make sure the new config is loaded by fsearch
    120.times do
      result = search("query=sddocname:test&nocache")
      rf = result.hit[0].field["summaryfeatures"]
      puts "summaryfeatures: '#{rf}'"
      if (rf.nil? || (rf == ""))
        sleep(1)
      else
        break
      end
    end

    assert_summaryfeatures
  end

  def test_omit_summary_features
    set_owner("geirst")
    set_description("Test that summary features can be omitted for a given document summary")
    deploy_app(SearchApp.new.sd(selfdir + "sd2/test.sd"))
    start
    feed(:file => selfdir + "doc.xml")

    result = search("query=body:test&summary=without_summary_features")
    assert_hitcount(result, 1)
    assert_field_value(result, "attr", 200)
    assert_nil(result.hit[0].field["summaryfeatures"],
               "Expected that 'summaryfeatures' field was omitted from document summary")
  end

  def assert_summaryfeatures()
    wait_for_hitcount("query=sddocname:test", 6)

    result = search("query=body:test")
    assert(result.hit.size == 1)
    assert_sf_hit(result, 0, 200)

    result = search("query=body:both")
    assert(result.hit.size == 2)
    assert_sf_hit(result, 0, 200)
    assert_sf_hit(result, 1, 100)

    result = search("query=sddocname:test&hits=2&offset=0&nocache")
    assert_equal(2, result.hit.size)
    assert_sf_hit(result, 0, 600)
    assert_sf_hit(result, 1, 500)

    result = search("query=sddocname:test&hits=2&offset=2&nocache")
    assert_equal(2, result.hit.size)
    assert_sf_hit(result, 0, 400)
    assert_sf_hit(result, 1, 300)

    result = search("query=sddocname:test&hits=2&offset=4&nocache")
    assert_equal(2, result.hit.size)
    assert_sf_hit(result, 0, 200)
    assert_sf_hit(result, 1, 100.0)

    # verify that summaryfeatures are presented as true floatingpoint values with '.0' after seemingly integer numbers.
    result = search("query=body:test&hits=1&nocache")
    assert_equal(1, result.hit.size)
    assert_equal({"attribute(attr)" => 200.0, "value(1)" => 1.0, "value(2)" => 2.0}, result.hit[0].field["summaryfeatures"])

    # verify that summaryfeatures are produced with grouping and hits=0 and the various cache combinations
    base_q = "query=body:test&select=all(group(attr)each(each(output(summary()))))&hits=0"
    sf_key = "group/grouplist/group/hitlist/hit/field[@name='summaryfeatures']"
    sf_val = '{"attribute(attr)":200.0,"value(1)":1.0,"value(2)":2.0,"vespa.summaryFeatures.cached":0.0}'

    result = search(base_q + "&groupingSessionCache=true&ranking.queryCache=false&format=xml")
    assert_equal(sf_val, result.xml.root.elements[sf_key].get_text.to_s)

    result = search(base_q + "&groupingSessionCache=false&ranking.queryCache=true&format=xml")
    assert_equal(sf_val, result.xml.root.elements[sf_key].get_text.to_s)

    result = search(base_q + "&groupingSessionCache=true&ranking.queryCache=true&format=xml")
    assert_equal(sf_val, result.xml.root.elements[sf_key].get_text.to_s)

  end

  def assert_sf_hit(result, hit, attr_value)
    sf = result.hit[hit].field["summaryfeatures"]
    puts "summaryfeatures for hit #{hit}: '#{sf}'"
    json = sf
    assert_equal(attr_value, result.hit[hit].field["attr"].to_i)
    assert_features({"value(1)" => 1.0}, json)
    assert_features({"value(2)" => 2.0}, json)
    assert_features({"attribute(attr)" => attr_value}, json)
  end

  def teardown
    stop
  end

end
