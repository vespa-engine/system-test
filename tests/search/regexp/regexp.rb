# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'cgi'


class RegExp < IndexedSearchTest

  def setup
    set_owner("havardpe")
  end

  def make_regexp(field, expr)
    my_regexp = "#{field} matches \"#{expr}\""
  end

  def make_term(field, word)
    my_term = "#{field} contains \"#{word}\""
  end

  def make_and(a, b)
    my_and = "(#{a} AND #{b})"
  end

  def make_query(a)
    my_query = "query=" + CGI::escape("select * from sources * where #{a};") + "&type=yql"
  end

  def check_regexp_hits(expr, chunk_hits)
    total_hits = chunk_hits * 3;
    for field in ["single_slow", "single_fast", "array_slow", "array_fast", "wset_slow", "wset_fast"]
      assert_hitcount(make_query(make_regexp(field, expr)), total_hits)
      for chunk in ["test1", "test2", "test3"]
        assert_hitcount(make_query(make_and(make_term("title", chunk), make_regexp(field, expr))), chunk_hits)
      end
    end
  end

  def test_regexp
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 9, :file => selfdir + "docs.xml")
    assert_hitcount(make_query(make_term("title", "test1")), 3);
    assert_hitcount(make_query(make_term("title", "test2")), 3);
    assert_hitcount(make_query(make_term("title", "test3")), 3);
    for field in ["single_slow", "single_fast", "array_slow", "array_fast", "wset_slow", "wset_fast"]
      assert_hitcount(make_query(make_term(field, "thisisafox")), 3);
      assert_hitcount(make_query(make_term(field, "thisisabear")), 3);
      assert_hitcount(make_query(make_term(field, "thisisafoxandabear")), 3);
    end

    # Verify that indexed fields will fallback to 'contains'.
    assert_hitcount(make_query(make_term("single_index", "thisisafox")), 3);
    assert_hitcount(make_query(make_regexp("single_index", "thisisafox")), 3);
    assert_hitcount(make_query(make_regexp("single_index", "^thisisafox")), 0);

    # prefix
    check_regexp_hits("^this", 3);
    check_regexp_hits("^thisisafox", 2);
    check_regexp_hits("^thisisafoxand", 1);
    check_regexp_hits("^is", 0);

    # suffix
    check_regexp_hits("fox$", 1);
    check_regexp_hits("bear$", 2);
    check_regexp_hits("andabear$", 1);
    check_regexp_hits("fish$", 0);

    # substring
    check_regexp_hits("isa", 3);
    check_regexp_hits("fox", 2);
    check_regexp_hits("bear", 2);
    check_regexp_hits("fish", 0);

    # compound
    check_regexp_hits("^this.*fox", 2);
    check_regexp_hits("^this.*fox$", 1);
    check_regexp_hits("^this.*bear", 2);
    check_regexp_hits("^this.*bear$", 2);
    check_regexp_hits("(fox$|bear$)", 3);
    check_regexp_hits("is.*and", 1);
    check_regexp_hits("fox.*bear", 1);
    check_regexp_hits("bear.*fox", 0);
    check_regexp_hits("[i]+[s]+", 3);
    check_regexp_hits("[i]+[b]+", 0);

    # Invalid regexp
    assert_query_errors(make_query(make_regexp("single_index", "*")),
                        ["Invalid search request .* Dangling meta character .* near index 0"])
  end

  def teardown
    stop
  end

end
