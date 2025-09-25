# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class SameElementOperator < IndexedStreamingSearchTest

  def setup
    set_owner("toregge")
  end

  def feed_doc(id, doc_template)
    doc = Document.new("id:test:test::#{id}").
            add_field("id", id).
            add_field("sa", doc_template[:sa])
    vespa.document_api_v1.put(doc)
  end

  def test_same_element_on_array_of_string
    set_description('Test sameElement operator on array of string')
    deploy_app(SearchApp.new.sd(selfdir + "test.sd").
                 indexing_cluster('default').indexing_chain('indexing'))
    start
    text0 = 'This is some text'
    text1 = 'and more text'
    text2 = 'This is even more text'
    feed_doc(0, { :sa => [ text0, text1, text2 ] })
    assert_equal({ 0 => [ text0, text1, text2 ] }, check_summary('sa contains sameElement("this", "text")', 'full'))
    assert_equal({ 0 => [ text0, text2 ] }, check_summary('sa contains sameElement("this", "text")', 'meo'))
    assert_equal({ 0 => [ text0, text1, text2 ] }, check_summary('sa contains sameElement("this" and "text")', 'full'))
    assert_equal({ 0 => [ text0, text2 ] }, check_summary('sa contains sameElement("this" and "text")', 'meo'))
    assert_equal({ }, check_summary('sa contains sameElement("some" and "more")', 'full'))
    assert_equal({ 0 => [ text2 ] }, check_summary('sa contains sameElement("more" and phrase("this", "is"))', 'meo'))
    assert_equal({ 0 => [ text1 ] }, check_summary('sa contains sameElement("more" and equiv("or", "and"))', 'meo'))
    assert_equal({ 0 => [ text1, text2 ] }, check_summary('sa contains sameElement("more" and equiv("even", "and"))', 'meo'))
    assert_equal({ 0 => [ text2 ] }, check_summary('sa contains sameElement("more" and ({distance:3}near("is", "text")))', 'meo'))
    assert_equal({ }, check_summary('sa contains sameElement("more" and ({distance:2}near("is", "text")))', 'meo'))
    assert_equal({ 0 => [ text2 ] }, check_summary('sa contains sameElement("more" and ({distance:3}onear("is", "text")))', 'meo'))
    assert_equal({ }, check_summary('sa contains sameElement("more" and ({distance:3}onear("text", "is")))', 'meo'))
  end

  def check_summary(query, summary)
    form = [['yql', "select * from sources * where #{query}"],
            ['summary', summary]]
    encoded_query_form = URI.encode_www_form(form)
    result = search(encoded_query_form)
    summary_result = Hash.new
    # Bypass result parsing to avoid sorting in Hit.add_field
    children = result.json['root']['children']
    unless children.nil?
      children.each do |hit|
        summary_result[hit['fields']['id']] = hit['fields']["sa_#{summary}"]
      end
    end
    return summary_result
  end


end
