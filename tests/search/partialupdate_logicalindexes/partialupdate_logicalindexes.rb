# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class PartialUpdateLogicalIndexes < IndexedSearchTest

  def setup
    set_owner("bratseth")
    set_description("Test that logical indexes can be partially updated.")
    deploy_app(SearchApp.new.sd(selfdir+"hotcars.sd").sd(selfdir+"airplanes.sd"))
    start
  end

  def each_field(query, fieldname, qrserver_id=0)
    result = search(query, qrserver_id)
    result.xml.elements.each("//hit/field[@name='#{fieldname}']") {
      | field | yield field
    }
  end

  def check(query, fieldName, expected)
    query += "&summary=attributeprefetch"
    query += "&nocache&format=xml"
    # @rescount = 0 unless @rescount
    # @rescount += 1
    # resfile = "tmp.res." + @rescount.to_s
    # puts "save #{query} in #{resfile}"
    # save_result(query + "&tracelevel=9", resfile)
    assert_hitcount(query, 1)
    each_field(query, fieldName) do |field|
      target_text = field.to_s
      # puts "EXP: #{expected.to_s}"
      # puts "WAS: #{target_text}"
      assert_match(expected, target_text)
    end
  end

  def test_pu_logicalindexes
    feed_and_wait_for_docs("hotcars", 2, :file => selfdir+"initial_feed.xml")

    wait_for_hitcount("popularity:>0", 3)
    validate_doc1_before_pu("query=manufacturer:lambourghini")
    validate_doc1_before_pu("query=manufacturer:lambourghini&search=hotcars")
    validate_doc1_before_pu("query=shops:Cheesy's+Used+Car+Shop*!*")
    # XXX this does not work, exactmatch problem with aliases:
    #validate_doc1_before_pu("query=dealers:Cheesy's+Used+Car+Shop*!*")
    validate_doc2_before_pu("query=manufacturer:ferrari")
    validate_doc2_before_pu("query=manufacturer:ferrari&search=hotcars")
    validate_doc2_before_pu("query=popularity:20")
    validate_doc3_before_pu("query=manufacturer:boeing")
    validate_doc3_before_pu("query=manufacturer:boeing&search=airplanes")
    validate_doc3_before_pu("query=vectors:22.5")

    feedfile(selfdir+"update_feed.xml")
    sleep 2

    assert_hitcount("popularity:>0", 3)
    validate_doc1_after_pu("query=manufacturer:lambourghini")
    validate_doc1_after_pu("query=manufacturer:lambourghini&search=hotcars")
    validate_doc1_after_pu("query=shops:Evil+Car+Chain+I*!*")
    # XXX this does not work, exactmatch problem with aliases:
    #validate_doc1_after_pu("query=dealers:Evil+Car+Chain+II*!*")
    validate_doc2_after_pu("query=manufacturer:ferrari")
    validate_doc2_after_pu("query=manufacturer:ferrari&search=hotcars")
    validate_doc2_after_pu("query=popularity:50")
    validate_doc3_after_pu("query=manufacturer:boeing")
    validate_doc3_after_pu("query=manufacturer:boeing&search=airplanes")
    validate_doc3_after_pu("query=vectors:22.5")
  end

  def validate_doc1_before_pu(query)
    check(query, "popularity", />10</)
    #check(query, "shops", /<item>God's Speed Cars<\/item>/)
    #check(query, "shops", /<item>Cars R Us<\/item>/)
    #check(query, "shops", /<item>Cheesy's Used Car Shop<\/item>/)
    check(query, "shops", /<item>god's speed cars<\/item>/)
    check(query, "shops", /<item>cars r us<\/item>/)
    check(query, "shops", /<item>cheesy's used car shop<\/item>/)
    check(query, "orders_per_state", /<item weight='0'>TX<\/item>/)
    check(query, "orders_per_state", /<item weight='0'>IL<\/item>/)
  end

  def validate_doc2_before_pu(query)
    check(query, "popularity", />20</)
    #check(query, "shops", /<item>God's Speed Cars<\/item>/)
    #check(query, "shops", /<item>Purely Red<\/item>/)
    check(query, "shops", /<item>god's speed cars<\/item>/)
    check(query, "shops", /<item>purely red<\/item>/)
    check(query, "orders_per_state", /<item weight='0'>TX<\/item>/)
    check(query, "orders_per_state", /<item weight='0'>IL<\/item>/)
  end

  def validate_doc3_before_pu(query)
    check(query, "popularity", />50</)
    check(query, "rating", /64\.7834/)
    check(query, "airlines", /<item>Air Columbia<\/item>/)
    check(query, "airlines", /<item>KLM<\/item>/)
    check(query, "vectors", /<item weight='100'>22\.5<\/item>/)
    check(query, "vectors", /<item weight='100'>50\.0<\/item>/)
  end

  def validate_doc1_after_pu(query)
    check(query, "popularity", />30</)
    #check(query, "shops", /<item>God's Speed Cars<\/item>/)
    #check(query, "shops", /<item>Cars R Us<\/item>/)
    #check(query, "shops", /<item>Evil Car Chain I<\/item>/)
    #check(query, "shops", /<item>Evil Car Chain II<\/item>/)
    check(query, "shops", /<item>god's speed cars<\/item>/)
    check(query, "shops", /<item>cars r us<\/item>/)
    check(query, "shops", /<item>evil car chain i<\/item>/)
    check(query, "shops", /<item>evil car chain ii<\/item>/)
    check(query, "orders_per_state", /<item weight='150'>TX<\/item>/)
    check(query, "orders_per_state", /<item weight='200'>IL<\/item>/)
    check(query, "orders_per_state", /<item weight='50'>MX<\/item>/)
  end

  def validate_doc2_after_pu(query)
    check(query, "popularity", />50</)
    #check(query, "shops", /<item>God's Speed Cars<\/item>/)
    #check(query, "shops", /<item>Purely Red<\/item>/)
    check(query, "shops", /<item>god's speed cars<\/item>/)
    check(query, "shops", /<item>purely red<\/item>/)
    check(query, "orders_per_state", /<item weight='5000'>TX<\/item>/)
    check(query, "orders_per_state", /<item weight='400'>TN<\/item>/)
  end

  def validate_doc3_after_pu(query)
    check(query, "popularity", />100</)
    check(query, "rating", /70\.44/)
    check(query, "airlines", /<item>SAS Braathens<\/item>/)
    check(query, "airlines", /<item>American Airlines<\/item>/)
    check(query, "vectors", /<item weight='140'>22\.5<\/item>/)
    check(query, "vectors", /<item weight='180'>50\.0<\/item>/)
    check(query, "vectors", /<item weight='100'>17\.986<\/item>/)
  end

  def teardown
    stop
  end

end
