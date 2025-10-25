# Copyright Vespa.ai. All rights reserved.
require 'indexed_streaming_search_test'

class NearSearch < IndexedStreamingSearchTest

  @@terms = [ "one", "brown", "fox", "jumped" ]

  def setup
    set_owner("yngve")
  end

  def test_phrases_via_near
    add_bundle(selfdir+"PhraseToONearSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.nearsearch.PhraseToONearSearcher", "transformedQuery", "blendedResult"))
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").search_chain(search_chain))
    start
    feed_and_wait_for_docs("music", 256, :file => "#{selfdir}/documents.json")

    run_phrases_via_near_test
    vespa.search["search"].first.trigger_flush
    run_phrases_via_near_test
  end

  def run_phrases_via_near_test
    assert_hitcount("query=sddocname:music&tracelevel=5", 256)
    result = search("query=sddocname:music&tracelevel=5")
    trace = result.json['trace']
    assert(trace.to_s =~ /there is no spoon returns/)
    docs = []
    File.open("#{selfdir}/documents.json") do |file|
      file.each do |line|
        if line.match(/id/)
          docs.push(line)
        end
      end
    end

    for i in [1, 2, 3]
      puts "*** Testing #{i}-term phrases."
      for query in gen_phrases(i)
        cnt = count_docs(docs, query)
        puts "Running query \"#{query}\", expecting #{cnt} hits."
        assert_hitcount("query=%22#{query}%22", cnt)
      end
    end

    # check ONEAR with multi-value fields
    puts search("query=songs:%22a+b+c%22").xmldata
    assert_hitcount("query=songs:%22a+b+c%22", 1)

    puts search("query=songs:%22c+b+a%22").xmldata
    assert_hitcount("query=songs:%22c+b+a%22", 1)
  end

  def test_near_for_array
    add_bundle("#{selfdir}/PhraseToNearSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.nearsearch.PhraseToNearSearcher", "transformedQuery", "blendedResult"))
    deploy_app(SearchApp.new.sd(selfdir+"music.sd").search_chain(search_chain))
    start
    feed_and_wait_for_docs("music", 256, :file => "#{selfdir}/documents.json")

    run_near_for_array_test
    vespa.search["search"].first.trigger_flush
    run_near_for_array_test
  end

  def run_near_for_array_test
    puts "Check that Searcher is actually running"
    data = search("query=sddocname:music&tracelevel=5&hits=0").xmldata
    #puts data
    assert(data.include?("PhraseToNearSearcher:"))

    # check NEAR with multi-value fields
    puts "Check a,b,c"
    #puts search("query=songs:%22a+b+c%22&tracelevel=1").xmldata
    assert_hitcount("query=songs:%22a+b+c%22", 3)

    puts "Check c,b,a"
    #puts search("query=songs:%22c+b+a%22&tracelevel=1").xmldata
    assert_hitcount("query=songs:%22c+b+a%22", 3)

    check_element_gap('default', 3)
    check_element_gap('element-gap-infinity', 3)
    check_element_gap('element-gap-17', 3)
    check_element_gap('element-gap-16', 5)
    check_element_gap('element-gap-0', 5)
    puts "All OK"
  end

  def check_element_gap(ranking, wanted_hits)
    puts "Check element gap: ranking=#{ranking}, wanted_hits=#{wanted_hits}"
    yql_abc = 'select * from sources * where songs contains ({distance:20}near("a","b","c"))'
    assert_hitcount({ 'yql' => yql_abc, 'ranking' => ranking }, wanted_hits)
  end


  def gen_phrases(numTerms)
    if (numTerms <= 1)
      return @@terms
    else
      list = []
      tail = gen_phrases(numTerms - 1)
      for term in @@terms
        for tailTerm in tail
          list.push(term + " " + tailTerm)
        end
      end
      return list
    end
  end

  def count_docs(docs, query)
    count = 0
    docs.each do |doc|
      if (doc.match(query))
        count = count + 1
      end
    end
    return count
  end

  def test_near_negative_terms
    deploy_app(SearchApp.new
      .sd(selfdir+"music.sd")
      .container(Container.new
        .config(ConfigOverride.new("container.qr-searchers")
          .add("sendProtobufQuerytree", true))
        .search(Searching.new)
        .docproc(DocumentProcessing.new)
        .documentapi(ContainerDocumentApi.new)))
    start
    feed_and_wait_for_docs("music", 256, :file => "#{selfdir}/documents.json")

    run_near_negative_terms_test
    vespa.search["search"].first.trigger_flush
    run_near_negative_terms_test
  end

  def run_near_negative_terms_test
    # Distance 2 allows 1 term between search terms

    # Get baseline counts
    near_count = search({'yql' => 'select * from sources * where title contains ({distance:2}near("one", "fox"))'}).hitcount
    onear_count = search({'yql' => 'select * from sources * where title contains ({distance:2}onear("one", "fox"))'}).hitcount
    phrase1_count = search({'yql' => 'select * from sources * where title contains phrase("one", "brown", "fox") AND !(title contains phrase("fox", "one"))'}).hitcount
    phrase2_count = search({'yql' => 'select * from sources * where title contains phrase("fox", "brown", "one") AND !(title contains phrase("one", "fox"))'}).hitcount
    phrase3_count = search({'yql' => 'select * from sources * where title contains phrase("one", "brown", "fox")'}).hitcount

    puts "Baseline: near=#{near_count}, onear=#{onear_count}, phrase1=#{phrase1_count}, phrase2=#{phrase2_count}, phrase3=#{phrase3_count}"
    assert(near_count > 0 && onear_count > 0 && phrase1_count > 0 && phrase2_count > 0 && phrase3_count > 0, "All baseline counts should be > 0")

    # Test with negative terms and exclusionDistance:0
    near_negative = search({'yql' => 'select * from sources * where title contains ({distance:2,exclusionDistance:0}near("one", "fox", !"brown"))'}).hitcount
    onear_negative = search({'yql' => 'select * from sources * where title contains ({distance:2,exclusionDistance:0}onear("one", "fox", !"brown"))'}).hitcount

    # Validate: negative term should exclude exact phrases
    expected_near = near_count - phrase1_count - phrase2_count
    expected_onear = onear_count - phrase3_count
    puts "Results: near_negative=#{near_negative} (expected #{expected_near}), onear_negative=#{onear_negative} (expected #{expected_onear})"
    assert_equal(expected_near, near_negative, "NEAR with negative term mismatch")
    assert_equal(expected_onear, onear_negative, "ONEAR with negative term mismatch")

    # Test with exclusionDistance:5 and existing term "brown"
    # Check how many baseline matches contain "brown" at all (fields are small, so it's always within distance 5)
    near_with_brown = search({'yql' => 'select * from sources * where title contains ({distance:2}near("one", "fox")) AND title contains "brown"'}).hitcount
    onear_with_brown = search({'yql' => 'select * from sources * where title contains ({distance:2}onear("one", "fox")) AND title contains "brown"'}).hitcount

    near_brown_5 = search({'yql' => 'select * from sources * where title contains ({distance:2,exclusionDistance:5}near("one", "fox", !"brown"))'}).hitcount
    onear_brown_5 = search({'yql' => 'select * from sources * where title contains ({distance:2,exclusionDistance:5}onear("one", "fox", !"brown"))'}).hitcount

    expected_near_brown_5 = near_count - near_with_brown
    expected_onear_brown_5 = onear_count - onear_with_brown
    puts "ExclusionDistance:5 with 'brown': near=#{near_brown_5} (expected #{expected_near_brown_5}), onear=#{onear_brown_5} (expected #{expected_onear_brown_5})"
    assert_equal(expected_near_brown_5, near_brown_5, "NEAR with exclusionDistance:5 and 'brown' mismatch")
    assert_equal(expected_onear_brown_5, onear_brown_5, "ONEAR with exclusionDistance:5 and 'brown' mismatch")
  end

end
