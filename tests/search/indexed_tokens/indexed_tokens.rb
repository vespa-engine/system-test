# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class IndexedTokensTest < IndexedSearchTest

  def setup
    set_owner("toregge")
  end

  def feed_doc(idsuffix, doc_template)
    doc = Document.new("test", "id:test:test::#{idsuffix}").
      add_field("stext", doc_template[:stext]).
      add_field("atext", doc_template[:atext]).
      add_field("wtext", doc_template[:wtext]).
      add_field("sattr", doc_template[:stext]).
      add_field("sattr_cased", doc_template[:stext]).
      add_field("aattr", doc_template[:atext]).
      add_field("wattr", doc_template[:wtext])
    vespa.document_api_v1.put(doc)
  end

  def test_lingustics_tokens
    set_description("Test tokens summary transform for inspecting indexed tokens")
    # Explicitly use OpenNlpLinguistics to get the same results between public and internal system test runs.
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               indexing_cluster("my-container").
               container(Container.new("my-container").
                         search(Searching.new).
                         docproc(DocumentProcessing.new).
                         component(Component.new("com.yahoo.language.opennlp.OpenNlpLinguistics"))).
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
    assert_equal(['hello world'], fields['sattr_tokens'])
    assert_equal(['Hello world'], fields['sattr_cased_tokens'])
    assert_equal([['this is simply'],['(more elements)']], fields['aattr_tokens'])
    assert_equal([['weighted here'],['and there']].sort, fields['wattr_tokens'].sort)
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
