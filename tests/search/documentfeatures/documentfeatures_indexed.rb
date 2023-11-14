# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DocumentFeaturesIndexed < IndexedSearchTest

  def setup
    set_owner("geirst")
  end

  #---------- fieldLength ----------#
  def test_field_length
    set_description("Test the fieldLength feature")
    deploy_app(SearchApp.new.sd(selfdir+"fieldlength.sd"))
    start
    feed_and_wait_for_docs("fieldlength", 3, :file => selfdir + "fieldlength.xml")
    wait_for_hitcount("query=sddocname:fieldlength", 3)

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
  def test_field_length_with_exact_match
    set_description("Test the fieldLength feature with exact match")
    deploy_app(SearchApp.new.sd(selfdir+"flexactstring.sd"))
    start
    feed_and_wait_for_docs("flexactstring", 2, :file => selfdir + "flexactstring.xml")
    wait_for_hitcount("query=sddocname:flexactstring", 2)

    assert_field_length_exactstring(1000000, "a", "a:unique", 0) # match: exact triggers bitvector.
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
