# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
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

    puts "All OK"
  end

  def teardown
    stop
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

end
