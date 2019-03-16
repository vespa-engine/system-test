# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class FefProfiles < IndexedSearchTest

  def setup
    set_owner("havardpe")
  end

  def test_profiles
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.xml")
    assert_hitcount("query=test", 1)

    result1 = search("query=test&rankfeatures&ranking=rank1")
    result2 = search("query=test&rankfeatures&ranking=rank2")

    assert(result1.hit.size == 1)
    assert(result2.hit.size == 1)

    score1 = result1.hit[0].field["relevancy"].to_f
    score2 = result2.hit[0].field["relevancy"].to_f

    assert_equal(15.0,  score1)
    assert_equal(200.0, score2)

    rf1 = result1.hit[0].field["rankfeatures"]
    rf2 = result2.hit[0].field["rankfeatures"]

    assert(/"test_cfgvalue\(a\)":15/ =~ rf1)
    assert(/"test_cfgvalue\(b\)":25/ =~ rf1)
    assert_nil(/"test_cfgvalue\(c\)":/ =~ rf1)

    assert(/"test_cfgvalue\(a\)":100/ =~ rf2)
    assert(/"test_cfgvalue\(b\)":200/ =~ rf2)
    assert(/"test_cfgvalue\(c\)":300/ =~ rf2)
  end

  def teardown
    stop
  end

end
