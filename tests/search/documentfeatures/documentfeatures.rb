# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class DocumentFeatures < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def test_attribute
    set_description("Test the attribute feature, fieldlength")
    deploy_app(SearchApp.new.
               sd(selfdir+"attribute.sd").
               sd(selfdir+"fieldlength.sd").
               sd(selfdir+"flexactstring.sd"))
    start
    feed_and_wait_for_docs("attribute", 1, :file => selfdir + "attribute.json")
    feed_and_wait_for_docs("fieldlength", 3, :file => selfdir + "fieldlength.json")
    feed_and_wait_for_docs("flexactstring", 2, :file => selfdir + "flexactstring.json")
    attribute_test
    field_length_test
    field_length_with_exact_match_test
  end

  def attribute_test()
    result = search("query=idx:a")
    puts "summaryfeatures: '#{result.hit[0].field["summaryfeatures"]}'"

    # integer attributes
    assert_attribute("attribute(si)",   10)
    assert_attribute("attribute(ai,0)", 10)
    assert_attribute("attribute(ai,1)", 20)
    assert_attribute("attribute(ai,2)", 0)
    assert_attribute("attribute(wi,10).weight",   100)
    assert_attribute("attribute(wi,10).contains", 1)
    assert_attribute("attribute(wi,20).weight",   0)
    assert_attribute("attribute(wi,20).contains", 0)

    # float attributes
    assert_attribute("attribute(sf)",   10.5)
    assert_attribute("attribute(af,0)", 10.5)
    assert_attribute("attribute(af,1)", 20.5)
    assert_attribute("attribute(af,2)", 0)

    # string attributes
    assert_attribute("attribute(ss)",   1.7409184128169565e-43)   # hash of 'first'
    assert_attribute("attribute(as,0)", 1.7409184128169565e-43)   # hash of 'first'
    assert_attribute("attribute(as,1)", 8.379872018783626e-76) # hash of 'second'
    assert_attribute("attribute(as,2)", 0)
    assert_attribute("attribute(ws,first).weight",   100)
    assert_attribute("attribute(ws,first).contains", 1)
    assert_attribute("attribute(ws,second).weight",   0)
    assert_attribute("attribute(ws,second).contains", 0)

    # partial updates on array fields
    feed(:file => selfdir + "attribute.upd.json")
    assert_attribute("attribute(ai,2)", 40)
    assert_attribute("attribute(af,2)", 40.5)
    assert_attribute("attribute(as,2)", -9.774744375149687e-197) # hash of 'fourth'
    assert_attribute("attribute(ai,3)", 30)
    assert_attribute("attribute(af,3)", 30.5)
    assert_attribute("attribute(as,3)", -1.7865425069493262e+45) # hash of 'third'
  end

  def assert_attribute(feature, score)
    result = search("query=idx:a")
    assert_features({feature => score}, result.hit[0].field['summaryfeatures'])
  end

  #---------- fieldLength ----------#
  def field_length_test
    puts("Test the fieldLength feature")

    assert_field_length(1, "a", "a",   0)
    assert_field_length(2, "b", "b",   0)
    assert_field_length(3, "c", "c:c", 0)
    assert_field_length(5, "a", "a",   1)
    assert_field_length(3, "b", "b",   1)
    assert_field_length(1, "c", "c:c", 1)

    # fieldlength does not work when no hits in the field
    query = "sddocname:fieldlength"
    assert_field_length(1000000, "a", query, 0)
    assert_field_length(1000000, "b", query, 0)
    assert_field_length(1000000, "c", query, 0)
    assert_field_length(1000000, "a", query, 1)
    assert_field_length(1000000, "b", query, 1)
    assert_field_length(1000000, "c", query, 1)
    assert_field_length(1000000, "a", query, 2)
    assert_field_length(1000000, "b", query, 2)
    assert_field_length(1000000, "c", query, 2)
  end

  def assert_field_length(length, field, query, docid)
    query = "query=" + query + "&parallel"
    result = search(query)
    result.sort_results_by("documentid")
    sf = result.hit[docid].field["summaryfeatures"]
    puts "summaryfeatures: '#{sf}'"
    assert_features({"fieldLength(#{field})" => length}, sf)
  end

  #---------- fieldLength with exact match ----------#
  def field_length_with_exact_match_test
    puts("Test the fieldLength feature with exact match")

    expected_field_length = 1000000
    assert_field_length_exactstring(expected_field_length, "a", "a:unique", 0) # match: exact triggers bitvector.
    assert_field_length_exactstring(1000000, "a", "sddocname:flexactstring", 0)
    assert_field_length_exactstring(1000000, "a", "sddocname:flexactstring", 1)
  end

  def assert_field_length_exactstring(fl, field, query, docid)
    query = "query=" + query
    result = search(query)
    result.sort_results_by("documentid")
    sf = result.hit[docid].field["summaryfeatures"]
    assert_features({"fieldLength(#{field})" => fl}, sf)
  end

  def teardown
    stop
  end

end
