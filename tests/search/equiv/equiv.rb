# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class Equiv < IndexedStreamingSearchTest

  def setup
    set_owner("havardpe")
    set_description("Test of EQUIV operator")
  end

  def test_qrs_equiv_plugin
    add_bundle(selfdir + "EquivTestSearcher.java")
    search_chain = SearchChain.new.
      add(Searcher.new("com.yahoo.test.EquivTestSearcher"))
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").search_chain(search_chain))
    start
    numdocs = `grep -c "<document" #{selfdir + "docs.xml"}`.to_i
    feed_and_wait_for_docs("test", numdocs, :file => selfdir + "docs.xml")

    result = search({'yql' => 'select * from sources * where (body contains "a" AND range(id, 10, 19));', 'equivtrigger' => 'a', 'tracelevel' => '2'})
    #puts "==> TRIGGER TEST ==>"
    #puts result.xml.to_s
    #puts "<== TRIGGER TEST <=="
    assert_equal(4, result.hit.size)
  end

  def test_equiv
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    numdocs = `grep -c "<document" #{selfdir + "docs.xml"}`.to_i
    feed_and_wait_for_docs("test", numdocs, :file => selfdir + "docs.xml")
    assert_equiv
  end

  def assert_equiv()
    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "basic test with different items inside EQUIV"
    # check that equiv works with term/int/phrase and returns appropriate amounts of hits
    result = search({'yql' => 'select * from sources * where (body contains equiv("a", "5", phrase("x", "y")) AND range(id, 10, 19));'})
    puts result.to_s
    assert_equal(3, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for attribute term items inside EQUIV"
    # check that equiv works with attribute and returns appropriate amount of hits
    result = search({'yql' => 'select * from sources * where tag contains equiv("foo", "bar");'})
    puts result.to_s
    assert_equal(3, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for rank parity inside EQUIV"
    # check that 'a EQUIV b' ranks 'a a', 'a b' and 'b b' the same.
    result = search({'yql' => 'select * from sources * where (body contains equiv("a", "b") AND range(id, 0, 9));'})
    puts result.to_s
    assert_equal(3, result.hit.size)
    assert_equal(result.hit[0].field["relevancy"].to_f, result.hit[1].field["relevancy"].to_f)
    assert_equal(result.hit[0].field["relevancy"].to_f, result.hit[2].field["relevancy"].to_f)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test that OR is different"
    result = search({'yql' => 'select * from sources * where ((body contains "a" OR body contains "b") AND range(id, 0, 9));'})
    puts result.to_s
    assert_equal(3, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for completeness"
    # check that equiv is handled as a single unit in terms of ranking
    result = search({'yql' => 'select * from sources * where body contains equiv("foo", "notfoo");'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    exp = { "fieldMatch(body).fieldCompleteness" => 1,
            "fieldMatch(body).queryCompleteness" => 1,
            "queryTermCount" => 1 }
    assert_features(exp, result.hit[0].field['summaryfeatures'])

    unless is_streaming
      puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
      puts "test that EQUIV and multiple alternatives can be combined"
      result = search({'yql' => 'select * from sources * where bodymultiple contains equiv("cars", "vehicles");'})
      puts result.to_s
      assert_equal(1, result.hit.size)
    end

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for phrase size"
    # check that phrase matches act as if they have size 1 (known weakness)
    result = search({'yql' => 'select * from sources * where body contains equiv(phrase("bar", "baz"), "notbar", "notbaz");'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    exp = { "fieldMatch(body).fieldCompleteness" => 0.5,
            "fieldMatch(body).queryCompleteness" => 1,
            "queryTermCount" => 1 }
    assert_features(exp, result.hit[0].field['summaryfeatures'])

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for occurrence merging"
    # check that occurrences are merged for matches across equiv subtrees
    # body content: t0 t1 t2 t1 t3 t2 t4 t3 t5

    result = search({'yql' => 'select * from sources * where body contains equiv("t1", "t2", "t3");'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    exp = { "queryTermCount" => 1,
            "fieldInfo(body).first" => 1,
            "fieldInfo(body).last" => 7,
            "fieldInfo(body).cnt" => 6 }
    assert_features(exp, result.hit[0].field["summaryfeatures"])

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for occurrence merging (now with duplicates)"
    # check that occurrences are merged for matches across equiv subtrees
    # and that duplicates are removed
    # body content: t0 t1 t2 t1 t3 t2 t4 t3 t5

    result = search({'yql' => 'select * from sources * where body contains equiv("t1", "t2", "t3", "t2", "t1", phrase("t1", "t2"));'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    exp = { "queryTermCount" => 1,
            "fieldInfo(body).first" => 1,
            "fieldInfo(body).last" => 7,
            "fieldInfo(body).cnt" => 6 }
    assert_features(exp, result.hit[0].field['summaryfeatures'])

    return if is_streaming

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for document frequency merging"

    epsilon = 1e-6

    result = search({'yql' => 'select * from sources * where (body contains "never" OR body contains equiv("a", "onlyonce"));', 'recall' => '+body:onlyonce'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_a1 = result.hit[0].field["relevancy"].to_f

    result = search({'yql' => 'select * from sources * where (body contains "never" OR body contains equiv("onlyonce", "a"));', 'recall' => '+body:onlyonce'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_a2 = result.hit[0].field["relevancy"].to_f
    assert_approx(rel_a1, rel_a2, epsilon, "different order inside EQUIV should give same relevancy")

    result = search({'yql' => 'select * from sources * where (body contains "never" OR body contains equiv("b", "onlyonce"));', 'recall' => '+body:onlyonce'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_b1 = result.hit[0].field["relevancy"].to_f

    result = search({'yql' => 'select * from sources * where (body contains "never" OR body contains equiv("onlyonce", "b"));', 'recall' => '+body:onlyonce'})
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_b2 = result.hit[0].field["relevancy"].to_f
    assert_approx(rel_b1, rel_b2, epsilon, "different order inside EQUIV should give same relevancy")
    assert(rel_a1 + epsilon < rel_b1, "more frequent term inside EQUIV should be less significant")

  end

  def teardown
    stop
  end

end
