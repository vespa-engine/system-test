# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class DynTeaserArrayTest < IndexedSearchTest

  def setup
    set_owner("toregge")
  end

  def feed_doc(idsuffix, doc_template)
    doc = Document.new("test", "id:test:test::#{idsuffix}").
      add_field("stext", doc_template[:stext]).
      add_field("atext", doc_template[:atext]).
      add_field("wtext", doc_template[:wtext])
    vespa.document_api_v1.put(doc)
  end

  def test_lingustics_tokens
    set_description("Test linguistics tokens dfw")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               enable_document_api)
    start
    feed_doc("0", { :stext => "Hello world",
                    :atext => [ "This is simply", "(more elements)"],
                    :wtext => { "Weighted here" => 24, "and there" => -3} })
    result = my_query('stext', 'hello')
    fields = result['root']['children'][0]['fields']
    assert_equal(['hello','world'], fields['stext_tokens'])
    assert_equal([['this','is','simply'],['more','elements']], fields['atext_tokens'])
    assert_equal([['weighted','here'],['and','there']].sort, fields['wtext_tokens'].sort)
  end


  def my_query(query_field, query_term)
    form = [['yql', "select * from sources * where #{query_field} contains '#{query_term}'"],
            ['summary', 'tokens']]
    query = URI.encode_www_form(form)
    result = search(query)
    assert_hitcount(result, 1)
    return JSON.parse(result.xmldata)
  end

  def teardown
    stop
  end

end
