# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class IndexedTokensTest < IndexedStreamingSearchTest

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
      add_field("wattr", doc_template[:wtext]).
      add_field("stext_long1", doc_template[:stext_long]).
      add_field("stext_long2", doc_template[:stext_long]).
      add_field("stext_longwords1", doc_template[:stext_longwords]).
      add_field("stext_longwords2", doc_template[:stext_longwords])
    vespa.document_api_v1.put(doc)
  end

  def test_lingustics_tokens
    set_description("Test tokens summary transform for inspecting indexed tokens")
    # Explicitly use OpenNlpLinguistics to get the same results between public and internal system test runs.
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
               indexing_cluster("my-container").
               container(Container.new("my-container").
                         search(Searching.new).
                         documentapi(ContainerDocumentApi.new).
                         docproc(DocumentProcessing.new).
                         component(Component.new("com.yahoo.language.opennlp.OpenNlpLinguistics"))))
    start
    feed_doc("0", { :stext => "Hello world",
                    :atext => [ "This is simply", "(more elements)"],
                    :wtext => { "Weighted here" => 24, "and there" => -3},
                    :stext_long => repeated_terms_string(20),
                    :stext_longwords => long_words_string })
    result = my_query('stext', 'hello')
    fields = result['root']['children'][0]['fields']
    assert_equal(['hello','world'], fields['stext_tokens'])
    assert_equal([['this','is','simply'],['more','elements']], fields['atext_tokens'])
    assert_equal([['weighted','here'],['and','there']].sort, fields['wtext_tokens'].sort)
    assert_equal(['hello world'], fields['sattr_tokens'])
    assert_equal(['Hello world'], fields['sattr_cased_tokens'])
    assert_equal([['this is simply'],['(more elements)']], fields['aattr_tokens'])
    assert_equal([['weighted here'],['and there']].sort, fields['wattr_tokens'].sort)
    assert_equal(repeated_terms_tokens(20, 100), fields['stext_long1_tokens'])
    assert_equal(repeated_terms_tokens(20, is_streaming ? 20 : 10), fields['stext_long2_tokens'])
    assert_equal(long_words_tokens(100), fields['stext_longwords1_tokens'])
    assert_equal(long_words_tokens(is_streaming ? 100 : 10), fields['stext_longwords2_tokens'])
  end


  def my_query(query_field, query_term)
    form = [['yql', "select * from sources * where #{query_field} contains '#{query_term}'"],
            ['summary', 'tokens']]
    query = URI.encode_www_form(form)
    result = search(query)
    assert_hitcount(result, 1)
    return JSON.parse(result.xmldata)
  end

  def long_words_string
    "these are looooooong xlooooooong words"
  end

  def long_words_tokens(limit)
    long_words_string.split.select{|token| token.length <= limit }
  end

  def repeated_terms_string(repeats)
    (1..repeats).to_a.join(" x ").concat(" x")
  end

  def repeated_terms_tokens(repeats, limit)
    if limit >= repeats
      repeated_terms_string(repeats).split
    else
      repeated_terms_string(limit).concat(" ", ((limit+1)..repeats).to_a.join(" ")).split
    end
  end

  def teardown
    stop
  end

end
