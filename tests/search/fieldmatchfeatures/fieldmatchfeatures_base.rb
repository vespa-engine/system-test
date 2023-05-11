# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'

module FieldMatchFeaturesBase

  def setup
    set_owner("geirst")
    @id_field = "documentid"
  end

  def run_field_match
    # check fieldMatch(a) (same as unit tests in searchlib)
    assert_match(1,      "a", 0)
    assert_match(0.9339, "a", 1)
    #assert_match(0,      "a", 2) # must have a hit

    assert_match(1,      "a+b", 3)
    assert_match(0.9558, "a+b", 4)
    assert_match(0.9463, "a+b", 5)
    assert_match(0.1296, "a+b", 6)
    assert_match(0.1288, "a+b", 7)

    assert_match(0.8647, "a+b+c", 8)
    assert_match(0.861,  "a+b+c", 9)
    assert_match(0.4869, "a+b+c", 10)
    assert_match(0.4853, "a+b+c", 11)
    assert_match(0.3621, "a+b+c", 12)
    assert_match(0.3619, "a+b+c", 13)
    assert_match(0.3584, "a+b+c", 14)

    assert_match(0.3421, "a+b+c&type=any", 15)
    assert_match(0.3474, "a+b+c&type=any", 16)

    # check .weight
    assert_weight(1,    "a")
    assert_weight(0.75, "a!300+b:b&type=any")
    assert_weight(0.25, "a+b:b!300&type=any")

    # TODO: check .significance and .importance when done


    # check non-default maxOccurrences (same as unit tests in searchlib)
    assert_occurrences(1,      0.6, 0.6, 0.6, 0.6, 17)
    assert_occurrences(0.9231, 0.6, 0.6, 0.6, 0.6, 18)
    assert_occurrences(0.6,    0.6, 0.6, 0.6, 0.6, 19)
    assert_occurrences(1,      1,   1,   1,   1,   20)
    assert_occurrences(1,      1,   1,   1,   1,   21)


    # check non-default maxAlternativeSegmentations (same as unit tests in searchlib)
    assert_segmentations(4, 0, 0.75,  0.075,  "segmentations-0") # segments found: a x x b and c d
    assert_segmentations(4, 0, 0.855, 0.0855, "segmentations-1") # segments found: a x b   and c d
    assert_segmentations(4, 0, 1,     0.1,    "segmentations-2") # segments found: a b     and c d


    # check non-default proximityCompletenessImportance
    assert_match(0.8689, "a+b+c&ranking=proximity-completeness", 8)
    assert_match(0.4882, "a+b+c&ranking=proximity-completeness", 10)


    # check non-default relatednessImportance
    assert_match(0.8647, "a+b+c&ranking=relatedness", 8)
    assert_match(0.4478, "a+b+c&ranking=relatedness", 10)


    # check non-default earlinessImportance
    assert_match(0.6914, "a+b+c&ranking=earliness", 8)
    assert_match(0.7306, "a+b+c&ranking=earliness", 10)


    # check non-default segmentProximityImportance
    assert_match(0.9289, "a+b+c&ranking=segment-proximity", 8)
    assert_match(0.2908, "a+b+c&ranking=segment-proximity", 10)


    # check non-default occurrenceImportance
    assert_match(0.5595, "a+b+c&ranking=occurrence", 8)
    assert_match(0.3084, "a+b+c&ranking=occurrence", 10)


    # check non-default fieldCompletenessImportance
    assert_match(0.0926, "a+b+c&ranking=field-completeness", 8)
    assert_match(0.0623, "a+b+c&ranking=field-completeness", 10)

    # check non-default proximityTable
    assert_proximity(0.52, "a+b+c", 11)
    assert_proximity(0.80, "a+b+c&ranking=proximity", 11)

    # check .queryCompleteness
    assert_querycompleteness(0.5,    "a+z&type=any", 4)
    assert_querycompleteness(1.0,    "a+b&type=any", 4)
    assert_querycompleteness(0.3333, "%22a+x%22+b&type=any", 4)
    assert_querycompleteness(0.6667, "%22a+b%22+z&type=any", 4)
    assert_querycompleteness(1.0,    "%22a+b%22+x&type=any", 4)
  end

  def assert_match(expected, query, docid)
    query = "query=" + query + "&parallel&hits=50"
    assert_field_match({"fieldMatch(a)" => expected}, query, docid)
  end

  def assert_querycompleteness(expected, query, docid)
    query = "query=" + query + "&parallel&hits=50"
    assert_field_match({"fieldMatch(a).queryCompleteness" => expected}, query, docid)
  end

  def assert_weight(expected, query, docid=0)
    query = "query=" + query + "&parallel&hits=50"
    assert_field_match({"fieldMatch(a).weight" => expected}, query, docid)
  end

  def assert_occurrences(occ, absolute_occ, weighted_occ, weighted_absolute_occ, significant_occ, docid)
    query = "query=a+b&parallel&hits=50&ranking=max-occs"
    expected = {"fieldMatch(a).occurrence" => occ,
                "fieldMatch(a).absoluteOccurrence" => absolute_occ, \
                "fieldMatch(a).weightedOccurrence" => weighted_occ, \
                "fieldMatch(a).weightedAbsoluteOccurrence" => weighted_absolute_occ}
                #"fieldMatch(a).significantOccurrence" => significant_occ} TODO: fix this when significance is working

    assert_field_match(expected, query, docid)
  end

  def assert_segmentations(matches, tail, prox, absolute_prox, ranking)
    query = "query=a+b+c+d&parallel&hits=50&ranking=#{ranking}"
    expected = {"fieldMatch(a).matches" => matches, \
                "fieldMatch(a).degradedMatches" => 0, \
                "fieldMatch(a).tail" => tail, \
                "fieldMatch(a).proximity" => prox, \
                "fieldMatch(a).absoluteProximity" => absolute_prox}

    assert_field_match(expected, query, 22)
  end

  def assert_proximity(proximity, query, docid)
    query = "query=" + query + "&parallel&hits=50"
    assert_field_match({"fieldMatch(a).proximity" => proximity}, query, docid)
  end

  def assert_field_match(expected, query, docid)
    result = search_with_timeout(5, query)
    found = false
    result.hit.each do |hit|
      if hit.field[@id_field] == "id:fieldmatch:fieldmatch:n=1:#{docid}"
        # same epsilon as searchlib unit tests
        assert_features(expected, hit.field['summaryfeatures'], 1e-4)
        found = true
        break
      end
    end
    assert(found, "Hit with documentid='id:fieldmatch:fieldmatch:n=1:#{docid}' not found when running '#{query}'")
  end

  def assert_literal_best(docid, query)
    query = "query=" + query
    assert_equal("id:fmliteral:fmliteral::#{docid}", search_with_timeout(5, query).hit[0].field["documentid"])
  end

  def assert_literal_matches(matches, query, docid)
    query = "query=" + query
    exp = {"fieldMatch(a_literal).matches" => matches}
    result = search_with_timeout(5, query)
    result.sort_results_by("documentid")
    assert_features(exp, result.hit[docid].field['summaryfeatures'])
  end

  def assert_fmfilter(score, query_completeness, weight, matches, query)
    query = "query=" + query + "&type=any"
    exp = {"fieldMatch(a)" => score, "fieldMatch(a).queryCompleteness" => query_completeness, \
           "fieldMatch(a).weight" => weight, "fieldMatch(a).matches" => matches, \
           "fieldMatch(a).degradedMatches" => matches, "fieldMatch(a).proximity" => 0, \
           "fieldMatch(a).orderness" => 0, "fieldMatch(a).longestSequence" => 0}
    assert_features(exp, search_with_timeout(5, query).hit[0].field['summaryfeatures'], 1e-3)
  end

  def run_field_term_match
    assert_field_term_match(0, 0,       3, "a")
    assert_field_term_match(1, 1000000, 0, "a")
    assert_field_term_match(2, 1000000, 0, "a")
    assert_field_term_match(0, 0,       3, "a+b")
    assert_field_term_match(1, 2,       2, "a+b")
    assert_field_term_match(2, 1000000, 0, "a+b")
    assert_field_term_match(0, 0,       3, "a+b+c")
    assert_field_term_match(1, 2,       2, "a+b+c")
    assert_field_term_match(2, 4,       1, "a+b+c")

    # reverse the query term ordering
    assert_field_term_match(0, 2,       2, "b+a")
    assert_field_term_match(1, 0,       3, "b+a")
    assert_field_term_match(2, 1000000, 0, "b+a")
    assert_field_term_match(0, 4,       1, "c+b+a")
    assert_field_term_match(1, 2,       2, "c+b+a")
    assert_field_term_match(2, 0,       3, "c+b+a")

    # term with no hit
    assert_field_term_match(0, 0,       3, "a+y")
    assert_field_term_match(1, 1000000, 0, "a+y")
    assert_field_term_match(2, 1000000, 0, "a+y")
  end

  def assert_field_term_match(termidx, firstpos, occurrences, query, field = "a")
    query = "query=" + query + "&parallel&type=any"
    result = search_with_timeout(5, query)
    sf = result.hit[0].field["summaryfeatures"]
    fn = "fieldTermMatch(#{field},#{termidx})"
    assert_features({fn + ".firstPosition" => firstpos, fn + ".occurrences" => occurrences}, sf)
  end

  def assert_struct_streaming(matches, fieldCompleteness, occurrences, query, field, docid)
    query = "query=" + query
    result = search_with_timeout(5, query)
    result.sort_results_by("documentid")
    exp = {"fieldMatch(#{field}).matches" => matches, \
           "fieldMatch(#{field}).fieldCompleteness" => fieldCompleteness, \
           "fieldTermMatch(#{field},0).occurrences" => occurrences}
    assert_features(exp, result.hit[docid].field['summaryfeatures'], 1e-3)
  end

  def run_phrase_test()
    wait_for_hitcount("query=sddocname:fmphrase", 1)

    assert_phrase_streaming(3, "query=f1:%22a+b+c%22",  "f1")
    assert_phrase_streaming(3, "query=f1:a+b+c",      "f1")
    assert_phrase_streaming(3, "query=f2:%22a+x+b%22",  "f2")
    assert_phrase_streaming(3, "query=f2:a+x+b",      "f2")

    assert_phrase_streaming(3, "query=%22a+b+c%22",     "f1")
    assert_phrase_streaming(3, "query=a+b+c",         "f1")
    assert_phrase_streaming(0, "query=%22a+b+c%22",     "f2")
    assert_phrase_streaming(3, "query=a+b+c",         "f2")

    assert_phrase_streaming(0, "query=%22a+x+b+x+c%22", "f1")
    assert_phrase_streaming(3, "query=a+x+b+x+c",     "f1")
    assert_phrase_streaming(5, "query=%22a+x+b+x+c%22", "f2")
    assert_phrase_streaming(5, "query=a+x+b+x+c",     "f2")

    assert_phrase_streaming(4, "query=%22a+b+c%22+d",   "f1")
    assert_phrase_streaming(4, "query=a+b+c+d",       "f1")
    assert_phrase_streaming(1, "query=%22a+b+c%22+d",   "f2")
    assert_phrase_streaming(4, "query=a+b+c+d",       "f2")

    assert_phrase_streaming(4, "query=%22a+b%22+%22c+d%22", "f1")
    assert_phrase_streaming(4, "query=a+b+c+d",         "f1")
    assert_phrase_streaming(0, "query=%22a+b%22+%22c+d%22", "f2")
    assert_phrase_streaming(4, "query=a+b+c+d",         "f2")

    assert_phrase_streaming(2, "query=%22a+b%22+%22x+d%22", "f1")
    assert_phrase_streaming(3, "query=a+b+x+d",         "f1")
    assert_phrase_streaming(2, "query=%22a+b%22+%22x+d%22", "f2")
    assert_phrase_streaming(4, "query=a+b+x+d",         "f2")

    assert_features({"fieldMatch(f1)" => 1}, search_with_timeout(5, "query=f1:%22a+b+c+d%22").hit[0].field['summaryfeatures'])
    assert_features({"fieldMatch(f1)" => 1}, search_with_timeout(5, "query=f1:a+b+c+d").hit[0].field['summaryfeatures'])
  end

  def assert_phrase_streaming(matches, query, field)
    result = search_with_timeout(5, query)
    assert_features({"fieldMatch(#{field}).matches" => matches}, result.hit[0].field['summaryfeatures'])
  end

  def teardown
    stop
  end

end
