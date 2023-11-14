# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class Phrases < IndexedSearchTest

  @@alpha = ["one","brown","fox","jumped"]

  def gen_phrases(terms)
    if terms<=1
      return @@alpha
    else
      list = []
      tail = gen_phrases(terms-1)
      for a in @@alpha
        for t in tail
          list.push(a+" "+t)
        end
      end
      return list
    end
  end

  def count_docs(docs,query)
    count = 0
    docs.each do |doc|
      if doc.match(query)
        count = count+1
      end
    end
    return count
  end


  def setup
    set_owner("geirst")
  end

  def test_phrases
    set_description("Index and search for phrases.")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd"))
    start
    feed_and_wait_for_docs("music", 256, :file => selfdir+"phrases.docs.xml")

    docs = []
    File.open(selfdir+"phrases.docs.xml") do |file|
      file.each do |line|
        if line.match(/<title>/)
          docs.push(line)
        end
      end
    end

    for i in [1,2,3]
      puts "Testing #{i}-term phrase"
      for query in gen_phrases(i)
        assert_hitcount("query=%22#{query}%22",count_docs(docs,query))
      end
    end
  end

  def check_rank(query)
    # need an extra term to get any effect of the higher term weight due to normalization in nativeRank
    query2 = query + "+dummy&type=any"
    query3 = query + "!200+dummy&type=any"

    assert_hitcount(query, 1);
    rank1 = search(query).hit[0].field["relevancy"].to_i
    assert(rank1 > 0, "Hit 0 does not have relevancy larger than 0")

    assert_hitcount(query2, 1);
    rank2 = search(query2).hit[0].field["relevancy"].to_i
    assert_hitcount(query3, 1);
    rank3 = search(query3).hit[0].field["relevancy"].to_i
    assert(rank3 > rank2, "Hit 0 does not have larger relevancy with term weight (!(#{rank3} > #{rank2}))")
  end

  def test_phrase_rank
    set_description("Test that we get ranking on phrase queries.")
    # static rank is not turned on
    deploy_app(SearchApp.new.sd(selfdir + "phraserank.sd"))
    start
    feed_and_wait_for_docs("phraserank", 4, :file => selfdir + "phraserank.xml")

    check_rank("query=%22alpha%22");
    check_rank("query=%22beta gamma%22");
    check_rank("query=%22delta epsilon zeta%22");
    check_rank("query=%22eta theta iota kappa%22");
  end

  def teardown
    stop
  end

end
