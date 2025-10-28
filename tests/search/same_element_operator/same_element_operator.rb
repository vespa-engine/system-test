# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'
require 'bm25_scorer'
require 'bm25_utils'

class SameElementOperator < IndexedStreamingSearchTest
  include Bm25Utils

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
    average_element_len = 4
    average_field_len = 12
    @doc_count = 1
    sa_reverse_index =
      { 'and'  => [[[0, 4], [1, 3], [0, 5]]],
        'and_eq_even'  => [[[0, 4], [1, 3], [1, 5]]],
        'even' => [[[0, 4], [0, 3], [1, 5]]],
        'is'   => [[[1, 4], [0, 3], [1, 5]]],
        'more' => [[[0, 4], [1, 3], [1, 5]]],
        'some' => [[[1, 4], [0, 3], [0, 5]]],
        'this' => [[[1, 4], [0, 3], [1, 5]]],
        'this_is' => [[[1, 4], [0, 3], [1, 5]]],
        'text' => [[[1, 4], [1, 3], [1, 5]]] }
    @sa_docfreqs =
      { 'and'  => 1,
        'and_eq_even' => 1,
        'even' => 1,
        'is'   => 1,
        'more' => 1,
        'some' => 1,
        'this' => 1,
        'this_is' => 1,
        'text' => 1 }
    sa_idfs = @sa_docfreqs.map{|w,f| [w, Bm25Scorer.idf(f, @doc_count) ]}.to_h
    scorer = Bm25Scorer.new(sa_idfs, average_element_len, average_field_len, sa_reverse_index)
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
    assert_equal({ 0 => [ text1, text2 ] }, check_summary('sa contains sameElement("even" or "more")', 'meo'))
    assert_equal({ 0 => [ text0, text2 ] }, check_summary('sa contains sameElement("notfound" or ("text" and "is"))', 'meo'))
    check_features('sa contains sameElement("this" and "text")',
                   expected_scores(['this', 'text'], scorer, [true, false, true]))
    check_features('sa contains sameElement("more" and ({distance:3}near("is","text")))',
                   expected_scores(['this', 'is','text'], scorer, [false, false, true]))
    check_features('sa contains sameElement("more" and equiv("even", "and"))',
                   expected_scores(['more', 'and_eq_even'], scorer, [false, true, true]))
    check_features('sa contains sameElement("more" and phrase("this", "is"))',
                   expected_scores(['more', 'this_is'], scorer, [false, false, true]))
  end

  def make_annotated_term(term)
    frequency = @sa_docfreqs[term]
    "({documentFrequency: {frequency: #{frequency}, count: #{@doc_count}}}\"#{term}\")"
  end

  def make_annotated_query(query)
    query.gsub(/"([^"]*)"/) { make_annotated_term($1) }
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

  def expected_scores(terms, scorer, element_filter)
    scorer.element_filter = element_filter
    exp_scores = [ ]
    1.times do |doc|
      score = 0.0
      elementwise_scores = nil
      terms.each do |term|
        score += scorer.bm25_score(term, doc)
        elementwise_scores = scorer.sum_scores(elementwise_scores, scorer.elementwise_bm25_score(term, doc))
      end
      exp_scores.push([score, elementwise_scores])
    end
    scorer.element_filter = nil
    exp_scores
  end

  def check_features(query, exp_scores)
    puts "check_features: query is #{query}"
    annotated_query = make_annotated_query(query)
    puts "check_features: annotated query is #{annotated_query}"
    puts "check_features: exp_scores is #{exp_scores}"
    elementwise_bm25_feature_name = 'elementwise(bm25(sa),x,double)'
    result = search({ 'yql' => "select * from sources * where #{annotated_query}",
                      'summary' => 'meo' })
    assert_equal(1, result.hit.size)
    for doc in 0...result.hit.size
      exp_bm25_score = exp_scores[doc][0]
      exp_elementwise_bm25_scores = exp_scores[doc][1]
      exp_elementwise_bm25_cells = nonzero_cells(exp_elementwise_bm25_scores)
      exp_features = {"bm25(sa)" => exp_bm25_score}
      mf = result.hit[doc].field["matchfeatures"]
      assert_features(exp_features, mf)
      assert_elementwise_bm25_feature(elementwise_bm25_feature_name, exp_elementwise_bm25_cells, mf)
      sf = result.hit[doc].field["summaryfeatures"]
      assert_features(exp_features, sf)
      assert_elementwise_bm25_feature(elementwise_bm25_feature_name, exp_elementwise_bm25_cells, sf)
    end
  end

end
