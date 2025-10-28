# Copyright Vespa.ai. All rights reserved.

require 'assertions'

# Utility class to calculate bm25 scores for a document.
# Used by Bm25FeatureTest and SameElementOperator

class Bm25Scorer
  include Assertions

  attr_reader :avg_element_length
  attr_reader :avg_field_length
  attr_accessor :element_filter
  attr_reader :reverse_index
  attr_reader :idfs

  def initialize(idfs, avg_element_length, avg_field_length, reverse_index)
    @idfs = idfs
    @avg_element_length = avg_element_length
    @avg_field_length = avg_field_length
    @reverse_index = reverse_index
    @element_filter = nil
  end

  def self.idf(matching_doc_count, total_doc_count)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    Math.log(1 + ((total_doc_count - matching_doc_count + 0.5) / (matching_doc_count + 0.5)))
  end

  def self.score(num_occs, field_length, inverse_doc_freq, avg_field_length)
    # This is the same formula as used in vespa/searchlib/src/vespa/searchlib/features/bm25_feature.cpp
    inverse_doc_freq * (num_occs * 2.2) / (num_occs + (1.2 * (0.25 + 0.75 * field_length / avg_field_length)))
  end

  def filtered_num_occs(num_occs)
    return num_occs if element_filter.nil?
    num_occs.each_with_index.map{ | cnt, element | element_filter[element] ? cnt : 0 }
  end

  def matches(term, doc)
    rev_idx = reverse_index[term][doc]
    return filtered_num_occs(rev_idx.transpose[0]).sum > 0
  end

  def bm25_score(term, doc)
    rev_idx = reverse_index[term][doc]
    num_occs = filtered_num_occs(rev_idx.transpose[0]).sum
    field_length = rev_idx.transpose[1].sum
    Bm25Scorer.score(num_occs, field_length, idfs[term], avg_field_length)
  end

  def elementwise_bm25_score(term, doc)
    rev_idx = reverse_index[term][doc]
    num_occs = filtered_num_occs(rev_idx.transpose[0])
    element_lengths = rev_idx.transpose[1]
    scores = []
    for element in 0...num_occs.size
      if num_occs[element] == 0
        scores.push(0)
      else
        scores.push(Bm25Scorer.score(num_occs[element], element_lengths[element], idfs[term], avg_element_length))
      end
    end
    scores
  end

  def sum_scores(scores, other_scores)
    if scores.nil?
      return other_scores
    end
    assert_equal(scores.size, other_scores.size)
    summed_scores = []
    for i in 0...scores.size
      summed_scores.push(scores[i] + other_scores[i])
    end
    summed_scores
  end
end
