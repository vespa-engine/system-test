# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_search_test'

class Equiv < IndexedSearchTest

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

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20%22a%22%20AND%20range%28id%2C%2010%2C%2019%29%29%3B&type=yql&equivtrigger=a&tracelevel=2")
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
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20equiv%28%22a%22%2C%20%225%22%2C%20phrase%28%22x%22%2C%20%22y%22%29%29%20AND%20range%28id%2C%2010%2C%2019%29%29%3B&type=yql")
    puts result.to_s
    assert_equal(3, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for attribute term items inside EQUIV"
    # check that equiv works with attribute and returns appropriate amount of hits
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20tag%20contains%20equiv%28%22foo%22%2C%20%22bar%22%29%3B&type=yql")
    puts result.to_s
    assert_equal(3, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for rank parity inside EQUIV"
    # check that 'a EQUIV b' ranks 'a a', 'a b' and 'b b' the same.
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20equiv%28%22a%22%2C%20%22b%22%29%20AND%20range%28id%2C%200%2C%209%29%29%3B&type=yql")
    puts result.to_s
    assert_equal(3, result.hit.size)
    assert_equal(result.hit[0].field["relevancy"].to_f, result.hit[1].field["relevancy"].to_f)
    assert_equal(result.hit[0].field["relevancy"].to_f, result.hit[2].field["relevancy"].to_f)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test that OR is different"
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28%28body%20contains%20%22a%22%20OR%20body%20contains%20%22b%22%29%20AND%20range%28id%2C%200%2C%209%29%29%3B&type=yql")
    puts result.to_s
    assert_equal(3, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for completeness"
    # check that equiv is handled as a single unit in terms of ranking
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20body%20contains%20equiv%28%22foo%22%2C%20%22notfoo%22%29%3B&type=yql")
    puts result.to_s
    assert_equal(1, result.hit.size)
    exp = { "fieldMatch(body).fieldCompleteness" => 1,
            "fieldMatch(body).queryCompleteness" => 1,
            "queryTermCount" => 1 }
    assert_features(exp, result.hit[0].field['summaryfeatures'])

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test that EQUIV and multiple alternatives can be combined"
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20bodymultiple%20contains%20equiv%28%22cars%22%2C%20%22vehicles%22%29%3B&type=yql")
    puts result.to_s
    assert_equal(1, result.hit.size)

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for phrase size"
    # check that phrase matches act as if they have size 1 (known weakness)
    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20body%20contains%20equiv%28phrase%28%22bar%22%2C%20%22baz%22%29%2C%20%22notbar%22%2C%20%22notbaz%22%29%3B&type=yql")
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

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20body%20contains%20equiv%28%22t1%22%2C%20%22t2%22%2C%20%22t3%22%29%3B&type=yql")
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

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20body%20contains%20equiv%28%22t1%22%2C%20%22t2%22%2C%20%22t3%22%2C%20%22t2%22%2C%20%22t1%22%2C%20phrase%28%22t1%22%2C%20%22t2%22%29%29%3B&type=yql")
    puts result.to_s
    assert_equal(1, result.hit.size)
    exp = { "queryTermCount" => 1,
            "fieldInfo(body).first" => 1,
            "fieldInfo(body).last" => 7,
            "fieldInfo(body).cnt" => 6 }
    assert_features(exp, result.hit[0].field['summaryfeatures'])

    puts "==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
    puts "test for document frequency merging"

    epsilon = 1e-6

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20%22never%22%20OR%20body%20contains%20equiv%28%22a%22%2C%20%22onlyonce%22%29%29%3B&type=yql&recall=%2Bbody:onlyonce")
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_a1 = result.hit[0].field["relevancy"].to_f

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20%22never%22%20OR%20body%20contains%20equiv%28%22onlyonce%22%2C%20%22a%22%29%29%3B&type=yql&recall=%2Bbody:onlyonce")
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_a2 = result.hit[0].field["relevancy"].to_f
    assert_approx(rel_a1, rel_a2, epsilon, "different order inside EQUIV should give same relevancy")

    result = search("query=select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20%22never%22%20OR%20body%20contains%20equiv%28%22b%22%2C%20%22onlyonce%22%29%29%3B&type=yql&recall=%2Bbody:onlyonce")
    puts result.to_s
    assert_equal(1, result.hit.size)
    rel_b1 = result.hit[0].field["relevancy"].to_f

    result = search("select%20%2A%20from%20sources%20%2A%20where%20%28body%20contains%20%22never%22%20OR%20body%20contains%20equiv%28%22onlyonce%22%2C%20%22b%22%29%29%3B&type=yql&recall=%2Bbody:onlyonce")
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
