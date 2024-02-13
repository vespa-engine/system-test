# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Bm25FeatureTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    @ignore_summary_features = false
  end

  def self.final_test_methods
    ['test_enable_bm25_feature']
  end

  def test_bm25_feature
    set_description("Test basic functionality of the bm25 rank feature")
    deploy_app(SearchApp.new.sd(selfdir + (is_streaming ? "streaming/test.sd" : "test.sd")))
    start

    # Note: Average field length for these documents = 4 ((7 + 3 + 2) / 3).
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")

    assert_bm25_scores
    assert_bm25_scores(3, 100, 'avgfl100')
    
    vespa.search["search"].first.trigger_flush
    assert_bm25_scores

    restart_proton("test", 3)
    assert_bm25_scores
  end

  def test_enable_bm25_feature
    @params = { :search_type => 'ELASTIC' }
    set_description("Test regeneration of interleaved features when enabling bm25 feature")
    @test_dir = selfdir + "regen/"
    deploy_app(SearchApp.new.sd("#{@test_dir}0/test.sd"))
    start
    # Average field length for content = 4 ((7 + 3 + 2) / 3).
    # Average field length for contenta = 8 ((14 + 6 + 4) / 3).
    feed_and_wait_for_docs("test", 3, :file => @test_dir + "docs.json")
    assert_no_bm25_scores
    assert_no_bm25_array_scores

    redeploy(SearchApp.new.sd("#{@test_dir}1/test.sd"))
    60.times do |i|
      puts "Waiting for interleaved features (#{i + 1})"
      break unless get_pending_urgent_flush
      sleep 1
    end
    assert_bm25_scores(3, 4)
    @ignore_summary_features = true
    assert_bm25_array_scores(3, 8)
    @ignore_summary_features = false
  end

  def make_query(terms, ranking, idfs)
    subqueries = []
    for term in terms
      if idfs.nil? || !idfs.include?(term)
        significance = ''
      else
        significance = "{significance: #{idfs[term]}}"
      end
      subqueries.push("content contains (#{significance}\"#{term}\")")
    end
    joined_subqueries = subqueries.join(" and ")
    form = [['yql', "select * from sources * where #{joined_subqueries}"],
            ['ranking', ranking]]
    encoded_form = URI.encode_www_form(form)
    puts "encoded form is #{encoded_form}"
    return encoded_form
  end

  def assert_bm25_scores(total_doc_count = 3, avg_field_length = 4, ranking = 'default')
    if is_streaming
      idfs = {}
      idfs['a'] = idf(3, total_doc_count)
      idfs['b'] = idf(2, total_doc_count)
      idfs['d'] = idf(2, total_doc_count)
    else
      idfs = nil
    end
    assert_scores_for_query(make_query(['a'], ranking, idfs), [score(2, 3, idf(3, total_doc_count), avg_field_length),
                                                   score(3, 7, idf(3, total_doc_count), avg_field_length),
                                                   score(1, 2, idf(3, total_doc_count), avg_field_length)])

    assert_scores_for_query(make_query(['b'], ranking, idfs), [score(1, 3, idf(2, total_doc_count), avg_field_length),
                                                   score(1, 7, idf(2, total_doc_count), avg_field_length)])

    assert_scores_for_query(make_query(['a','d'], ranking, idfs), [score(1, 2, idf(3, total_doc_count), avg_field_length) + score(1, 2, idf(2, total_doc_count), avg_field_length),
                                                             score(3, 7, idf(3, total_doc_count), avg_field_length) + score(1, 7, idf(2, total_doc_count), avg_field_length)])
  end

  def assert_bm25_array_scores(total_doc_count, avg_field_length)
    assert_scores_for_query("contenta:a&type=all", [score(2, 6, idf(3, total_doc_count), avg_field_length),
                                                    score(3, 14, idf(3, total_doc_count), avg_field_length),
                                                    score(1, 4, idf(3, total_doc_count), avg_field_length)])

    assert_scores_for_query("contenta:b&type=all", [score(1, 6, idf(2, total_doc_count), avg_field_length),
                                                    score(1, 14, idf(2, total_doc_count), avg_field_length)])

    assert_scores_for_query("content:a+content:d&type=all", [score(1, 4, idf(3, total_doc_count), avg_field_length) + score(1, 4, idf(2, total_doc_count), avg_field_length),
                                                             score(3, 14, idf(3, total_doc_count), avg_field_length) + score(1, 14, idf(2, total_doc_count), avg_field_length)])
  end

  def assert_no_bm25_scores
    assert_scores_for_query("content:a&type=all", [0.0, 0.0, 0.0])

    assert_scores_for_query("content:b&type=all", [0.0, 0.0])

    assert_scores_for_query("content:a+content:d&type=all", [0.0, 0.0])
  end

  def assert_no_bm25_array_scores
    assert_scores_for_query("contenta:a&type=all", [0.0, 0.0, 0.0])

    assert_scores_for_query("contenta:b&type=all", [0.0, 0.0])

    assert_scores_for_query("content:a+content:d&type=all", [0.0, 0.0])
  end

  def idf(matching_doc_count, total_doc_count = 3)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    Math.log(1 + ((total_doc_count - matching_doc_count + 0.5) / (matching_doc_count + 0.5)))
  end

  def score(num_occs, field_length, inverse_doc_freq, avg_field_length = 4)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    inverse_doc_freq * (num_occs * 2.2) / (num_occs + (1.2 * (0.25 + 0.75 * field_length / avg_field_length)))
  end

  def assert_scores_for_query(query, exp_scores)
    result = search(query)
    exp_scores = exp_scores.sort.reverse
    assert_hitcount(result, exp_scores.length)
    for i in 0...exp_scores.length do
      assert_relevancy(result, exp_scores[i], i)
      sf = result.hit[i].field["summaryfeatures"]
      if (exp_scores[i] > 0.0 || !sf.nil?) && !@ignore_summary_features
        assert_features({"bm25(content)" => exp_scores[i]}, sf)
      end
    end
  end

  def get_pending_urgent_flush
    result = vespa.search['search'].first.get_state_v1_custom_component("/documentdb/test/subdb/ready/index")
    return result['pending_urgent_flush']
  end

  def teardown
    stop
  end

end
