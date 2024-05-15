# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Bm25FeatureTest < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def self.final_test_methods
    ['test_enable_bm25_feature', 'test_bm25_idf']
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
    @params = { :search_type => 'INDEXED' }
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
    assert_bm25_array_scores(3, 8)
  end

  class DocCounts
    attr_accessor :total, :matching

    def initialize(total, matching)
      @total = total
      @matching = matching # matching[index][field]
    end

    def max_of_saturated_sums
      # Calculate saturated sum for each index, cf. OrBlueprint::combine
      # then max, cf. SourceBlenderBlueprint::combine
      @matching.map { |index| [ index.sum, @total ].min }.max
    end

    def max_of_field(field)
      # Calculate max, cf. SourceBlenderBlueprint::combine
      @matching.transpose[field].max
    end

    def merge_indexes
      @matching = @matching.transpose.map { |field| [ field.sum ] }.transpose
    end
  end

  def test_bm25_idf
    @params = { :search_type => 'INDEXED' }
    set_description("Test idf calculation for indexed bm25 feature")
    @test_dir = selfdir + "idf/"
    deploy_app(SearchApp.new.sd("#{@test_dir}/test.sd"))
    start

    doc_counts = DocCounts.new(7, [[3, 5]])
    feed_and_wait_for_docs("test", doc_counts.total, :file => @test_dir + "docs1.json")
    # For field "content", "a" matches 3 documents in memory index.
    assert_matching_doc_count_is_saturated_sum_for_fields(doc_counts: doc_counts)
    # Flush memory index to disk
    vespa.search["search"].first.trigger_flush
    # For field "content", "a" matches 3 documents in disk index.
    assert_matching_doc_count_is_saturated_sum_for_fields(doc_counts: doc_counts)
    doc_counts.total = 11
    doc_counts.matching.push([4, 0])
    feed_and_wait_for_docs("test", doc_counts.total, :file => @test_dir + "docs2.json")
    # For field "content", "a" matches 3 documents in disk index and 4
    # documents in memory index.
    assert_matching_doc_count_is_saturated_sum_for_fields(doc_counts: doc_counts)
    # Flush memory index to disk (will occasionally also run fusion)
    vespa.search["search"].first.trigger_flush
    # Run fusion on two disk indexes
    vespa.search["search"].first.trigger_flush
    doc_counts.merge_indexes
    # For field "content", "a" matches 7 documents in disk index.
    assert_matching_doc_count_is_saturated_sum_for_fields(doc_counts: doc_counts)
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
                                                   score(1, 2, idf(3, total_doc_count), avg_field_length)], 'content')

    assert_scores_for_query(make_query(['b'], ranking, idfs), [score(1, 3, idf(2, total_doc_count), avg_field_length),
                                                   score(1, 7, idf(2, total_doc_count), avg_field_length)], 'content')

    assert_scores_for_query(make_query(['a','d'], ranking, idfs), [score(1, 2, idf(3, total_doc_count), avg_field_length) + score(1, 2, idf(2, total_doc_count), avg_field_length),
                                                             score(3, 7, idf(3, total_doc_count), avg_field_length) + score(1, 7, idf(2, total_doc_count), avg_field_length)], 'content')
  end

  def assert_bm25_array_scores(total_doc_count, avg_field_length)
    assert_scores_for_query("contenta:a&type=all", [score(2, 6, idf(3, total_doc_count), avg_field_length),
                                                    score(3, 14, idf(3, total_doc_count), avg_field_length),
                                                    score(1, 4, idf(3, total_doc_count), avg_field_length)], 'contenta')

    assert_scores_for_query("contenta:b&type=all", [score(1, 6, idf(2, total_doc_count), avg_field_length),
                                                    score(1, 14, idf(2, total_doc_count), avg_field_length)], 'contenta')

    assert_scores_for_query("content:a+content:d&type=all", [score(1, 4, idf(3, total_doc_count), avg_field_length) + score(1, 4, idf(2, total_doc_count), avg_field_length),
                                                             score(3, 14, idf(3, total_doc_count), avg_field_length) + score(1, 14, idf(2, total_doc_count), avg_field_length)], 'content')
  end

  def assert_no_bm25_scores
    assert_scores_for_query("content:a&type=all", [0.0, 0.0, 0.0], 'content')

    assert_scores_for_query("content:b&type=all", [0.0, 0.0], 'content')

    assert_scores_for_query("content:a+content:d&type=all", [0.0, 0.0], 'content')
  end

  def assert_no_bm25_array_scores
    assert_scores_for_query("contenta:a&type=all", [0.0, 0.0, 0.0], 'contenta')

    assert_scores_for_query("contenta:b&type=all", [0.0, 0.0], 'contenta')

    assert_scores_for_query("content:a+content:d&type=all", [0.0, 0.0], 'content')
  end

  def idf(matching_doc_count, total_doc_count = 3)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    Math.log(1 + ((total_doc_count - matching_doc_count + 0.5) / (matching_doc_count + 0.5)))
  end

  def score(num_occs, field_length, inverse_doc_freq, avg_field_length = 4)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    inverse_doc_freq * (num_occs * 2.2) / (num_occs + (1.2 * (0.25 + 0.75 * field_length / avg_field_length)))
  end

  def assert_scores_for_query(query, exp_scores, field)
    result = search(query)
    exp_scores = exp_scores.sort.reverse
    assert_hitcount(result, exp_scores.length)
    for i in 0...exp_scores.length do
      assert_relevancy(result, exp_scores[i], i)
      sf = result.hit[i].field["summaryfeatures"]
      if (exp_scores[i] > 0.0 || !sf.nil?)
        assert_features({"bm25(#{field})" => exp_scores[i]}, sf)
      end
      mf = result.hit[i].field["matchfeatures"]
      if (exp_scores[i] > 0.0 || !mf.nil?)
        assert_features({"bm25(#{field})" => exp_scores[i]}, mf)
      end
    end
  end

  def get_pending_urgent_flush
    result = vespa.search['search'].first.get_state_v1_custom_component("/documentdb/test/subdb/ready/index")
    return result['pending_urgent_flush']
  end

  def assert_matching_doc_count_is_saturated_sum_for_fields(doc_counts:, avg_field_length_content: 4, avg_field_length_extra: 4)
    assert_scores_for_id_index_term_query(make_id_index_term_query('1', 'content', 'a'),
                                          score(2, 3, idf(doc_counts.max_of_field(0), doc_counts.total), avg_field_length_content),
                                          0.0)
    assert_scores_for_id_index_term_query(make_id_index_term_query('1', 'extra', 'a'),
                                          0.0,
                                          score(3, 7, idf(doc_counts.max_of_field(1), doc_counts.total), avg_field_length_extra))
    assert_scores_for_id_index_term_query(make_id_index_term_query('1', 'both', 'a'),
                                          score(2, 3, idf(doc_counts.max_of_saturated_sums, doc_counts.total), avg_field_length_content),
                                          score(3, 7, idf(doc_counts.max_of_saturated_sums, doc_counts.total), avg_field_length_extra))
  end

  def saturated_sum(counts, limit)
    # Calculate saturated sum, cf. OrBlueprint::combine
    sum = counts.sum
    sum = limit if sum > limit
    sum
  end

  def make_id_index_term_query(id, index, term)
    form = [['yql', "select * from sources * where #{index} contains \"#{term}\" and id contains \"#{id}\""]]
    encoded_form = URI.encode_www_form(form)
    puts "encoded form is #{encoded_form}"
    return encoded_form
  end

  def assert_scores_for_id_index_term_query(query, exp_score_content, exp_score_extra)
    result = search(query)
    assert_hitcount(result, 1)
    exp_features = {'bm25(content)' => exp_score_content, 'bm25(extra)' => exp_score_extra}
    puts "Expected features: #{exp_features}"
    assert_relevancy(result, exp_score_content + exp_score_extra, 0)
    sf = result.hit[0].field['summaryfeatures']
    assert_features(exp_features, sf)
    mf = result.hit[0].field['matchfeatures']
    assert_features(exp_features, mf)
  end

  def teardown
    stop
  end

end
