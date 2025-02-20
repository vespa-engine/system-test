# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class Bm25FeatureTest < IndexedStreamingSearchTest
  attr_reader :content_reverse_index
  attr_reader :contenta_reverse_index

  class Annotation
  end

  class DocumentFrequency < Annotation
    attr_reader :frequency, :count
    def initialize(frequency, count)
      @frequency = frequency
      @count = count
    end

    def annotation
      "{documentFrequency: {frequency: #{frequency}, count: #{count}}}"
    end
  end

  class Significance < Annotation
    attr_reader :significance
    def initialize(significance)
      @significance = significance
    end

    def annotation
      "{significance: #{significance}}"
    end
  end

  class QueryBuilder
    attr_reader :total_doc_count, :field
    attr_reader :document_frequencies, :ranking
    attr_reader :idfs, :annotations
    def initialize(testcase, total_doc_count, field, document_frequencies, ranking, add_significance: false, add_docfreq: false)
      @testcase = testcase
      @total_doc_count = total_doc_count
      @field = field
      @document_frequencies = document_frequencies
      @ranking = ranking
      testcase.assert(add_docfreq || add_significance || !testcase.is_streaming)
      @idfs = { }
      @document_frequencies.each do |term, freq|
        @idfs[term] = testcase.idf(freq, total_doc_count)
      end
      @annotations = nil
      if add_docfreq
        @annotations = { }
        document_frequencies.each do |term, freq|
          @annotations[term] = DocumentFrequency.new(freq, total_doc_count)
        end
      elsif add_significance
        @annotations = { }
        idfs.each do |term, idf|
          @annotations[term] = Significance.new(idf)
        end
      end
    end

    def make_query(terms)
      subqueries = []
      for term in terms
        annotation = ''
        if !annotations.nil? && annotations.include?(term)
          annotation = annotations[term].annotation
        end
        subqueries.push("#{field} contains (#{annotation}\"#{term}\")")
      end
      joined_subqueries = subqueries.join(" and ")
      form = [['yql', "select * from sources * where #{joined_subqueries}"],
              ['ranking', ranking]]
      encoded_form = URI.encode_www_form(form)
      @testcase.puts "yql is #{form[0][1]}"
      @testcase.puts "encoded form is #{encoded_form}"
      return encoded_form
    end
  end

  class Scorer
    attr_reader :query_builder
    attr_reader :avg_element_length
    attr_reader :avg_field_length
    attr_reader :reverse_index
    attr_reader :idfs

    def initialize(testcase, query_builder, avg_element_length, avg_field_length, reverse_index)
      @testcase = testcase
      @query_builder = query_builder
      @avg_element_length = avg_element_length
      @avg_field_length = avg_field_length
      @reverse_index = reverse_index
      @idfs = query_builder.idfs
    end

    def matches(term, doc)
      rev_idx = reverse_index[term][doc]
      return rev_idx.transpose[0].sum > 0
    end

    def bm25_score(term, doc)
      rev_idx = reverse_index[term][doc]
      num_occs = rev_idx.transpose[0].sum
      field_length = rev_idx.transpose[1].sum
      @testcase.score(num_occs, field_length, idfs[term], avg_field_length)
    end

    def elementwise_bm25_score(term, doc)
      rev_idx = reverse_index[term][doc]
      num_occs = rev_idx.transpose[0]
      element_lengths = rev_idx.transpose[1]
      scores = []
      for element in 0...num_occs.size
        if num_occs[element] == 0
          scores.push(0)
        else
          scores.push(@testcase.score(num_occs[element], element_lengths[element], idfs[term], avg_element_length))
        end
      end
      scores
    end

    def sum_scores(scores, other_scores)
      if scores.nil?
        return other_scores
      end
      @testcase.assert_equal(scores.size, other_scores.size)
      summed_scores = []
      for i in 0...scores.size
        summed_scores.push(scores[i] + other_scores[i])
      end
      summed_scores
    end
  end

  class DegradedScorer < Scorer
    def initialize(testcase, query_builder, avg_element_length, avg_field_length, reverse_index)
      super(testcase, query_builder, avg_element_length, avg_field_length, reverse_index)
    end

    def bm25_score(term, doc)
      idfs[term]
    end
  end

  def setup
    set_owner("geirst")
    @content_reverse_index =
      { 'a' => [[[3, 7]], [[2, 3]], [[1, 2]]],
        'b' => [[[1, 7]], [[1, 3]], [[0, 2]]],
        'd' => [[[1, 7]], [[0, 3]], [[1, 2]]] }
    @contenta_reverse_index =
      { 'a' => [[[2, 7],[1, 7]], [[0, 3],[2, 3]], [[1, 2],[0, 2]]],
        'b' => [[[1, 7],[0, 7]], [[0, 3],[1, 3]], [[0, 2],[0, 2]]],
        'd' => [[[1, 7],[0, 7]], [[0, 3],[0, 3]], [[0, 2],[1, 2]]] }
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
    assert_bm25_array_scores(3, 8)
    
    vespa.search["search"].first.trigger_flush
    assert_bm25_scores
    assert_bm25_array_scores(3, 8)

    restart_proton("test", 3)
    assert_bm25_scores
    assert_bm25_array_scores(3, 8)
  end

  def test_enable_bm25_feature
    @params = { :search_type => 'INDEXED' }
    set_description("Test regeneration of interleaved features when enabling bm25 feature")
    @test_dir = selfdir + "regen/"
    deploy_app(SearchApp.new.sd("#{@test_dir}0/test.sd"))
    start
    # Average field length for content = 4 ((7 + 3 + 2) / 3).
    # Average field length for contenta = 8 ((14 + 6 + 4) / 3).
    feed_and_wait_for_docs("test", 3, :file => selfdir + "docs.json")
    assert_degraded_bm25_scores(3, 4)
    assert_degraded_bm25_array_scores(3, 8)

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

  def content_document_frequencies
    { 'a' => 3, 'b' => 2, 'd' => 2 }
  end

  def tweaked_content_document_frequencies
    { 'a' => 2, 'b' => 1, 'd' => 3 }
  end

  def assert_bm25_scores(total_doc_count = 3, avg_field_length = 4, ranking = 'default')
    assert_bm25_scores_helper(total_doc_count, avg_field_length, ranking) unless is_streaming
    assert_bm25_scores_helper(total_doc_count, avg_field_length, ranking, add_significance: true)
    assert_bm25_scores_helper(total_doc_count, avg_field_length, ranking, add_significance: true, tweak_document_frequencies: true)
    assert_bm25_scores_helper(total_doc_count, avg_field_length, ranking, add_docfreq: true)
    assert_bm25_scores_helper(total_doc_count, avg_field_length, ranking, add_docfreq: true, tweak_document_frequencies: true)
  end

  def assert_bm25_scores_helper(total_doc_count, avg_field_length, ranking, add_significance: false, add_docfreq: false, tweak_document_frequencies: false)
    assert(add_docfreq || add_significance || !is_streaming)
    document_frequencies = content_document_frequencies
    if tweak_document_frequencies
      assert(add_docfreq || add_significance)
      document_frequencies = tweaked_content_document_frequencies
    end
    query_builder = QueryBuilder.new(self, total_doc_count, 'content', document_frequencies, ranking, add_significance: add_significance, add_docfreq: add_docfreq)
    scorer = Scorer.new(self, query_builder, avg_field_length, avg_field_length, content_reverse_index)
    idfs = query_builder.idfs
    assert_scores_for_query(query_builder, scorer, ['a'],
                            [score(2, 3, idfs['a'], avg_field_length),
                             score(3, 7, idfs['a'], avg_field_length),
                             score(1, 2, idfs['a'], avg_field_length)],
                            'content')

    assert_scores_for_query(query_builder, scorer, ['b'],
                            [score(1, 3, idfs['b'], avg_field_length),
                             score(1, 7, idfs['b'], avg_field_length)],
                            'content')

    assert_scores_for_query(query_builder, scorer, ['a','d'],
                            [score(1, 2, idfs['a'], avg_field_length) +
                             score(1, 2, idfs['d'], avg_field_length),
                             score(3, 7, idfs['a'], avg_field_length) +
                             score(1, 7, idfs['d'], avg_field_length)],
                            'content')
  end

  def contenta_document_frequencies
    { 'a' => 3, 'b' => 2, 'd' => 2 }
  end

  def assert_bm25_array_scores(total_doc_count, avg_field_length)
    assert_bm25_array_scores_helper(total_doc_count, avg_field_length) unless is_streaming
    assert_bm25_array_scores_helper(total_doc_count, avg_field_length, add_docfreq: true)
  end

  def assert_bm25_array_scores_helper(total_doc_count, avg_field_length, add_docfreq: false)
    query_builder = QueryBuilder.new(self, total_doc_count, 'contenta', contenta_document_frequencies, 'default', add_docfreq: add_docfreq)
    scorer = Scorer.new(self, query_builder, avg_field_length.to_f / 2, avg_field_length, contenta_reverse_index)
    idfs = query_builder.idfs
    assert_scores_for_query(query_builder, scorer, ['a'],
                            [score(2, 6, idfs['a'], avg_field_length),
                             score(3, 14, idfs['a'], avg_field_length),
                             score(1, 4, idfs['a'], avg_field_length)],
                            'contenta')

    assert_scores_for_query(query_builder, scorer, ['b'],
                            [score(1, 6, idfs['b'], avg_field_length),
                             score(1, 14, idfs['b'], avg_field_length)],
                            'contenta')

    assert_scores_for_query(query_builder, scorer, ['a','d'],
                            [score(1, 4, idfs['a'], avg_field_length) + score(1, 4, idfs['d'], avg_field_length),
                             score(3, 14, idfs['a'], avg_field_length) + score(1, 14, idfs['d'], avg_field_length)],
                            'contenta')
  end

  def assert_degraded_bm25_scores(total_doc_count, avg_field_length)
    query_builder = QueryBuilder.new(self, total_doc_count, 'content', content_document_frequencies, 'default')
    scorer = DegradedScorer.new(self, query_builder, avg_field_length, avg_field_length, content_reverse_index)
    assert_scores_for_query(query_builder, scorer, ['a'],
                            [idf(3, total_doc_count),
                             idf(3, total_doc_count),
                             idf(3, total_doc_count)],
                            'content')
    assert_scores_for_query(query_builder, scorer, ['b'],
                            [idf(2, total_doc_count),
                             idf(2, total_doc_count)],
                            'content')
    assert_scores_for_query(query_builder, scorer, ['a','d'],
                            [idf(3, total_doc_count) + idf(2, total_doc_count),
                             idf(3, total_doc_count) + idf(2, total_doc_count)],
                            'content')
  end

  def assert_degraded_bm25_array_scores(total_doc_count, avg_field_length)
    query_builder = QueryBuilder.new(self, total_doc_count, 'contenta', contenta_document_frequencies, 'default')
    scorer = DegradedScorer.new(self, query_builder, avg_field_length / 2, avg_field_length, contenta_reverse_index)
    assert_scores_for_query(query_builder, scorer, ['a'],
                            [idf(3, total_doc_count),
                             idf(3, total_doc_count),
                             idf(3, total_doc_count)],
                            'contenta')
    assert_scores_for_query(query_builder, scorer, ['b'],
                            [idf(2, total_doc_count),
                             idf(2, total_doc_count)],
                            'contenta')
    assert_scores_for_query(query_builder, scorer, ['a','d'],
                            [idf(3, total_doc_count) + idf(2, total_doc_count),
                             idf(3, total_doc_count) + idf(2, total_doc_count)],
                            'contenta')
  end

  def idf(matching_doc_count, total_doc_count = 3)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    Math.log(1 + ((total_doc_count - matching_doc_count + 0.5) / (matching_doc_count + 0.5)))
  end

  def score(num_occs, field_length, inverse_doc_freq, avg_field_length = 4)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    inverse_doc_freq * (num_occs * 2.2) / (num_occs + (1.2 * (0.25 + 0.75 * field_length / avg_field_length)))
  end

  def assert_elementwise_bm25_feature(feature_name, exp_cells, features)
    feature = features[feature_name]
    puts "assert_elementwise_bm25_feature: feature=#{feature}"
    assert(feature.is_a?(Hash))
    assert(feature.include?('type') && feature.include?('cells') && feature.keys.size == 2)
    assert_equal("tensor(x{})", feature['type'])
    cells = feature['cells']
    assert(cells.is_a?(Hash))
    assert_equal(cells.keys.sort, exp_cells.keys.sort)
    cells.each do |k, v|
      exp_v = exp_cells[k]
      assert_approx(exp_v, v, 1e-6, "Value for cell #{k} differs")
    end
  end

  def nonzero_cells(scores)
    scores.each_with_index.map { |score, idx| [ idx.to_s, score ] }.delete_if { |x| x[1] == 0 }.to_h
  end

  def assert_scores_for_query(query_builder, scorer, terms, legacy_exp_scores, legacy_field)
    assert_equal(query_builder.field, legacy_field)
    field = query_builder.field
    query = query_builder.make_query(terms)
    exp_scores = []
    3.times do |doc|
      score = 0.0
      elementwise_scores = nil
      hit = true
      terms.each do |term|
        hit = false unless scorer.matches(term, doc)
        score += scorer.bm25_score(term, doc)
        elementwise_scores = scorer.sum_scores(elementwise_scores, scorer.elementwise_bm25_score(term, doc))
      end
      exp_scores.push([doc, score, elementwise_scores]) if hit
    end
    result = search(query)
    documentid_to_hit_idx = {}
    for i in 0...result.hit.size
      documentid = result.hit[i].field['documentid']
      documentid_to_hit_idx[documentid.split(':')[4].to_i] = i
    end
    legacy_exp_scores = legacy_exp_scores.sort.reverse
    exp_scores = exp_scores.sort { |a, b| documentid_to_hit_idx[a[0]] <=> documentid_to_hit_idx[b[0]] }
    assert_equal(legacy_exp_scores, exp_scores.transpose[1])
    assert_hitcount(result, exp_scores.length)
    puts "exp_scores = #{exp_scores}"
    for i in 0...exp_scores.length do
      exp_bm25_score = exp_scores[i][1]
      exp_elementwise_bm25_scores = exp_scores[i][2]
      exp_elementwise_bm25_cells = nonzero_cells(exp_elementwise_bm25_scores)
      exp_features = {"bm25(#{field})" => exp_bm25_score}
      elementwise_bm25_feature_name = "elementwise(bm25(#{field}),x,double)"
      assert_relevancy(result, exp_bm25_score, i)
      sf = result.hit[i].field["summaryfeatures"]
      if (exp_bm25_score > 0.0 || !sf.nil?)
        assert_features(exp_features, sf)
        assert_elementwise_bm25_feature(elementwise_bm25_feature_name, exp_elementwise_bm25_cells, sf)
      end
      mf = result.hit[i].field["matchfeatures"]
      if (exp_bm25_score > 0.0 || !mf.nil?)
        assert_features(exp_features, mf)
        assert_elementwise_bm25_feature(elementwise_bm25_feature_name, exp_elementwise_bm25_cells, mf)
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
