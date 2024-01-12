# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'search/wand/wanddocgenerator'

class WeakAnd < IndexedStreamingSearchTest

  def setup
  end

  def get_wand(tokens, wand_type = "")
    wand = "wand.field=features&wand.tokens=%7B#{tokens}%7D"
    if wand_type.eql?("parallel")
      wand += "&wand.type=parallel"
    end
    return wand
  end

  def get_app(sd_folder)
    SearchApp.new.sd(selfdir + "sdfiles/#{sd_folder}/test.sd")
  end

  def gen_and_feed(gen_mod, num_docs, gen_function)
    gen = WandDocGenerator.new(gen_mod)
    file = dirs.tmpdir + "temp.#{gen_function}.#{gen_mod}.#{num_docs}.xml"
    gen.send(gen_function, 1, num_docs).write_xml(file)
    feed_and_wait_for_docs("test", num_docs, :file => file)
    return gen
  end

  def test_wset_wand_ranking_vespa
    set_description("Test Vespa Wand ranking with weighted set field")
    run_wset_wand_ranking_test("vespa", "")
  end

  def test_wset_wand_ranking_parallel
    set_description("Test Parallel Wand ranking with weighted set field")
    run_wset_wand_ranking_test("parallel", "parallel")
  end

  def test_wset_wand_ranking_parallel_no_upper_bounds
    set_description("Test Parallel Wand ranking with weighted set field when no real upper bounds are available")
    run_wset_wand_ranking_test("parallel_noupperbounds", "parallel")
  end

  def run_wset_wand_ranking_test(sd_folder, wand_type)
    @wand_type = wand_type
    set_owner("geirst")
    deploy_app(get_app(sd_folder))
    start
    gen = gen_and_feed(7, 97, "gen_ranking_docs")

    gen.words.sort.each do |word,hits|
      verify_all_topk_hits(word, hits)
    end
  end

  def verify_all_topk_hits(word, exp_hits)
    hitcount = exp_hits.size
    query = "?" + get_wand("#{word}:1", @wand_type)
    puts "Expects #{query} -> #{hitcount} hits"
    assert_hitcount(query + "&hits=400", hitcount)
    for i in 1..hitcount do
      verify_topk_hits(query + "&hits=#{i}", i, exp_hits)
    end
  end

  def verify_topk_hits(query, topk, exp_hits)
    puts "About to verify #{query} -> #{topk} topk hits"
    result = search(query)
    # descending sort that matches the default rank profile sort order
    sorted_hits = exp_hits.sort {|x,y| y <=> x}
    assert_topk_hits(result, topk, sorted_hits)
  end

  def assert_topk_hits(result, topk, exp_hits)
    assert_equal(topk, result.hit.size, "Expected #{topk} hits, but got #{result.hit.size}")
    for i in 0...topk do
      exp_docid = exp_hits[i][0]
      exp_score = exp_hits[i][1].to_f
      puts "Expects hit[#{i}]: documentid(#{exp_docid}), relevancy(#{exp_score})"
      assert_equal(exp_docid, result.hit[i].field['documentid'])
      assert_relevancy(result, exp_score, i)
    end
  end


  def test_wset_wand_filter_vespa
    set_description("Test Vespa Wand with weighted set field and additional filter")
    run_wset_wand_filter_test("vespa", "")
  end

  def test_wset_wand_filter_parallel
    set_description("Test Parallel Wand with weighted set field and additional filter")
    run_wset_wand_filter_test("parallel", "parallel")
  end

  def test_wset_wand_filter_parallel_no_upper_bounds
    set_description("Test Parallel Wand with weighted set field and additional filter when no real upper bounds are available")
    run_wset_wand_filter_test("parallel_noupperbounds", "parallel")
  end

  def run_wset_wand_filter_test(sd_folder, wand_type)
    @wand_type = wand_type
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir + "sdfiles/#{sd_folder}/test.sd"))
    vespa.adminserver.logctl("searchnode:proton.server.searchabledocsubdb", "debug=on")
    start
    gen = gen_and_feed(7, 97, "gen_filter_docs")

    foo = "?#{get_wand('all:1', @wand_type)}&hits=400"
    puts "EINAR " + foo
    assert_hitcount(foo, 97)
    gen.words.sort.each do |word,hits|
      verify_filter_hits(word, hits)
    end
  end

  def verify_filter_hits(word, exp_hits)
    hitcount = exp_hits.size
    query = "?query=filter:#{word}&#{get_wand('all:1', @wand_type)}&hits=400"
    puts "Expects #{query} -> #{hitcount} hits"
    result = search(query)
    assert_hitcount(result, hitcount)
    # descending sort that matches the default rank profile sort order
    sorted_hits = exp_hits.sort {|x,y| y <=> x}
    sorted_hits.each_index do |i|
      exp_docid = sorted_hits[i][0]
      puts "Expects hit[#{i}].documentid == #{exp_docid}"
      assert_equal(exp_docid, result.hit[i].field['documentid'])
    end
  end

  def test_empty_wset_wand_vespa
    set_description("Test Vespa Wand with empty weighted set field")
    run_empty_wset_wand_test("vespa", "")
  end

  def test_empty_wset_wand_parallel
    set_description("Test Parallel Wand with empty weighted set field")
    run_empty_wset_wand_test("parallel", "parallel")
  end

  def run_empty_wset_wand_test(sd_folder, wand_type)
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir + "sdfiles/#{sd_folder}/test.sd"))
    start
    feed_and_wait_for_docs("test", 3, :file => selfdir+"docs/empty-wset.xml")

    assert_hitcount("?#{get_wand('a:1', wand_type)}", 2)
  end

  def test_wand_with_score_threshold_parallel
    set_description("Test that we can specify an initial score threshold using Parallel WAND")
    run_wand_with_score_threshold_test("parallel", "parallel")

    feed_and_wait_for_docs("test", 73, :file => selfdir+"docs/large-score-threshold.xml")
    query = "?" + get_wand("b:70000", @wand_type) + "&wand.scoreThreshold=4200000000&hits=100"
    assert_topk_hits(search(query), 1, [["id:test:test::101",4.9E9]])
  end

  def run_wand_with_score_threshold_test(sd_folder, wand_type)
    @wand_type = wand_type
    set_owner("geirst")
    deploy_app(get_app(sd_folder))
    start
    gen = gen_and_feed(2, 71, "gen_ranking_docs")

    verify_score_threshold_hits("a0", gen.words["a0"])
  end

  def verify_score_threshold_hits(word, exp_hits)
    # descending sort that matches the default rank profile sort order
    sorted_hits = exp_hits.sort {|x,y| y <=> x}
    for i in 0...sorted_hits.size
      sub_hits = sorted_hits.slice(0, sorted_hits.size-i)
      verify_score_threshold_sub_hits(word, sub_hits, sub_hits.last[1]-1)
    end
    verify_score_threshold_sub_hits(word, [], sorted_hits.first[1])
  end

  def verify_score_threshold_sub_hits(word, sub_hits, score_threshold)
    query = "?" + get_wand("#{word}:1", @wand_type) + "&wand.scoreThreshold=#{score_threshold}&hits=100"
    puts "About to verify #{query} -> #{sub_hits.size} hits"
    assert_topk_hits(search(query), sub_hits.size, sub_hits)
  end


  def teardown
    stop
  end

end
