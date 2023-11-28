# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class InOperator < IndexedSearchTest
  def setup
    set_owner("toregge")
  end

  def feed_doc(id, doc_template)
    doc = Document.new("test", "id:test:test::#{id}").
            add_field("id", id).
            add_field("is", doc_template[:is]).
            add_field("ia", doc_template[:ia]).
            add_field("iw", doc_template[:iw]).
            add_field("ss", doc_template[:ss]).
            add_field("sa", doc_template[:sa]).
            add_field("sw", doc_template[:sw])
    vespa.document_api_v1.put(doc)
  end

  def test_in_operator
    set_description("test yql in operator")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").enable_document_api)
    start
    feed_doc(0, { :is => 24,
                  :ia => [ 24, 27, 30],
                  :iw => { 24 => 1, 27 => 1, 30 => 1 },
                  :ss => "w24",
                  :sa => [ "w24", "w27", "w30" ],
                  :sw => { "w24" => 1, "w27" => 1, "w30" => 1 } })
    feed_doc(1, { :is => 30,
                  :ia => [ 30, 33, 36],
                  :iw => { 30 => 1, 33 => 1, 36 => 1 },
                  :ss => "w30",
                  :sa => [ "w30", "w33", "w36" ],
                  :sw => { "w30" => 1, "w33" => 1, "w36" => 1 } })
    feed_doc(2, { :is => 36,
                  :ia => [ 36, 39, 42],
                  :iw => { 36 => 1, 39 => 1, 42 => 1 },
                  :ss => "w36",
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
    # Empty result in line below is due to query term not being lowercased
    assert_equal([], my_query("ss in ('W24')", []))
    assert_equal([0], my_query("ssfs in ('W24')", []))
    assert_equal([], my_query("ssc in ('W24')", []))
    assert_equal([], my_query("ssfsc in ('W24')", []))
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

  def teardown
    stop
  end
end
