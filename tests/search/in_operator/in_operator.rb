# coding: utf-8
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class InOperator < IndexedStreamingSearchTest
  def setup
    set_owner("toregge")
  end

  def feed_doc(id, doc_template)
    doc = Document.new("test", "id:test:test::#{id}").
            add_field("id", id).
            add_field("is", doc_template[:is]).
            add_field("is2", doc_template[:is2]).
            add_field("ia", doc_template[:ia]).
            add_field("iw", doc_template[:iw]).
            add_field("ss", doc_template[:ss]).
            add_field("ss2", doc_template[:ss2]).
            add_field("sa", doc_template[:sa]).
            add_field("sw", doc_template[:sw])
    vespa.document_api_v1.put(doc)
  end

  def test_in_operator
    set_description("test yql in operator")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
                 indexing_cluster('default').indexing_chain('indexing').
                 enable_document_api)
    start
    feed_doc(0, { :is => 24,
                  :is2 => 25,
                  :ia => [ 24, 27, 30],
                  :iw => { 24 => 1, 27 => 1, 30 => 1 },
                  :ss => "w24",
                  :ss2 => "w25",
                  :sa => [ "w24", "w27", "w30" ],
                  :sw => { "w24" => 1, "w27" => 1, "w30" => 1 } })
    feed_doc(1, { :is => 30,
                  :is2 => 31,
                  :ia => [ 30, 33, 36],
                  :iw => { 30 => 1, 33 => 1, 36 => 1 },
                  :ss => "w30",
                  :ss2 => "w31",
                  :sa => [ "w30", "w33", "w36" ],
                  :sw => { "w30" => 1, "w33" => 1, "w36" => 1 } })
    feed_doc(2, { :is => 36,
                  :is2 => 37,
                  :ia => [ 36, 39, 42],
                  :iw => { 36 => 1, 39 => 1, 42 => 1 },
                  :ss => "w36",
                  :ss2 => "w37",
                  :sa => [ "w36", "w39", "w42" ],
                  :sw => { "w36" => 1, "w39" => 1, "w42" => 1 } })
    for fs in ['', 'fs']
      assert_equal([0], my_query("is#{fs} in (24)", []))
      assert_equal([0], my_query("ia#{fs} in (24)", []))
      assert_equal([0], my_query("iw#{fs} in (24)", []))
      assert_equal([0,1], my_query("is#{fs} in (@foo)", [['foo', '24,30']]))
      assert_equal([0,1], my_query("is#{fs} in (@foo,24)", [['foo', '30']]))
      for c in ['', 'c']
        assert_equal([0], my_query("ss#{fs}#{c} in ('w24')", []))
        assert_equal([0], my_query("sa#{fs}#{c} in ('w24')", []))
        assert_equal([0], my_query("sw#{fs}#{c} in ('w24')", []))
        assert_equal([0,2], my_query("ss#{fs}#{c} in (@foo)", [['foo', 'w24,w36']]))
        assert_equal([0,2], my_query("ss#{fs}#{c} in (@foo)", [['foo', '"w24","w36"']]))
        assert_equal([0,2], my_query("ss#{fs}#{c} in (@foo)", [['foo', "'w24','w36'"]]))
        assert_equal([1,2], my_query("sa#{fs}#{c} in (@foo)", [['foo', 'w33,w39']]))
      end
    end
    assert_equal([0], my_query("ss in ('W24')", []))
    assert_equal([0], my_query("ssfs in ('W24')", []))
    assert_equal([], my_query("ssc in ('W24')", []))
    assert_equal([], my_query("ssfsc in ('W24')", []))
    assert_equal([0], my_query("ssi in ('w24')", []))
    assert_equal([0], my_query("sai in ('w24')", []))
    assert_equal([0], my_query("swi in ('w24')", []))
    assert_equal([0,2], my_query("ssi in (@foo)", [['foo', 'w24,w36']]))
    assert_equal([0,2], my_query("ssi in (@foo)", [['foo', 'W24,W36']]))
    assert_equal([1,2], my_query("sai in (@foo)", [['foo', 'w33,w39']]))
    assert_equal([1,2], my_query("swi in (@foo)", [['foo', 'w33,w39']]))
    assert_equal([0,1], my_query("swi in ('w30')", []))
    assert_equal([0], my_query("ssit in ('w24')", []))
    assert_equal([0,1], my_query("ssit in ('w30')", []))
    assert_equal([1,2], my_query("ssit in ('w36')", []))
    assert_equal({0 => ['is'], 1 => ['is2'], 2 => ['is', 'is2']}, check_matches("ints in (24,31,36,37)"))
    assert_equal({0 => ['ia', 'is', 'iw'], 1 => ['is2'], 2 => ['ia', 'is2','iw']}, check_matches("ints2 in (24,31,37,39)"))
    assert_equal({0 => ['ss'], 1 => ['ss2'], 2 => ['ss', 'ss2']}, check_matches("strings in ('w24','w31','w36','w37')"))
    assert_equal({0 => ['sa', 'ss', 'sw'], 1 => ['ss2'], 2 => ['sa', 'ss2', 'sw']}, check_matches("strings2 in ('w24','w31','w37','w39')"))
    assert_equal({0 => ['ssi'], 1 => ['ss2i'], 2 => ['ss2i', 'ssi']}, check_matches("stringsi in ('w24','w31','w36','w37')"))
    assert_equal({0 => ['sai', 'ssi', 'swi'], 1 => ['ss2i'], 2 => ['sai', 'ss2i', 'swi']}, check_matches("strings2i in ('w24','w31','w37','w39')"))
    assert_equal({0 => ['ss'], 1 => ['ss2i'], 2 => ['ss', 'ss2i']}, check_matches("stringsai in ('w24','w31','w36','w37')"))
  end

  def my_query(query_string, query_params)
    form = [['yql', "select * from sources * where #{query_string}"]]
    form.concat(query_params) unless query_params.nil?
    encoded_query_form = URI.encode_www_form(form)
    result = search(encoded_query_form)
    id_result = Array.new
    result.hit.each do |hit|
      id_result.push(hit.field['id'])
    end
    return id_result
  end

  def check_matches(query_string)
    form = [['yql', "select * from sources * where #{query_string}"]]
    encoded_query_form = URI.encode_www_form(form)
    result = search(encoded_query_form)
    matches_fields_result = Hash.new
    result.hit.each do |hit|
      summaryfeatures = hit.field['summaryfeatures']
      matches_fields = Array.new
      for sf in summaryfeatures.keys
        if sf.match('^matches\(([0-9a-z]*)\)')
          matches_field = $1
          if summaryfeatures[sf] > 0
            matches_fields.push(matches_field)
          end
        end
      end
      matches_fields_result[hit.field['id']] = matches_fields.sort
    end
    return matches_fields_result
  end

  def teardown
    stop
  end
end
