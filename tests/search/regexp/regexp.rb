# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'cgi'


class RegExp < IndexedStreamingSearchTest

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
    my_query = "query=" + CGI::escape("select * from sources * where #{a}") + "&type=yql"
  end

  def check_regexp_hits(expr, chunk_hits, fields)
    total_hits = chunk_hits * 3;
    for field in fields
      assert_hitcount(make_query(make_regexp(field, expr)), total_hits)
      for chunk in ["test1", "test2", "test3"]
        assert_hitcount(make_query(make_and(make_term("title", chunk), make_regexp(field, expr))), chunk_hits)
      end
    end
  end

  def check_cased
    fields = ["single_scan_cased", "single_btree_cased", "single_hash_cased"]
    for field in fields
      assert_hitcount(make_query(make_term(field, "thisisafox")), 0);
      assert_hitcount(make_query(make_term(field, "thisisabear")), 0);
      assert_hitcount(make_query(make_term(field, "thisisafoxandabear")), 0);
    end
    for field in fields
      assert_hitcount(make_query(make_term(field, "ThisIsAFox")), 3);
      assert_hitcount(make_query(make_term(field, "ThisIsABear")), 3);
      assert_hitcount(make_query(make_term(field, "ThisIsAFoxAndABear")), 3);
    end
    # prefix
    check_regexp_hits("^this", 0, fields);
    check_regexp_hits("^thisisafox", 0, fields);
    check_regexp_hits("^thisisafoxand", 0, fields);
    check_regexp_hits("^is", 0, fields);

    check_regexp_hits("^This", 3, fields);
    check_regexp_hits("^ThisIsAFox", 2, fields);
    check_regexp_hits("^ThisIsAFoxAnd", 1, fields);
    check_regexp_hits("^Is", 0, fields);

    # suffix
    check_regexp_hits("fox$", 0, fields);
    check_regexp_hits("bear$", 0, fields);
    check_regexp_hits("andabear$", 0, fields);
    check_regexp_hits("fish$", 0, fields);

    check_regexp_hits("Fox$", 1, fields);
    check_regexp_hits("Bear$", 2, fields);
    check_regexp_hits("AndABear$", 1, fields);

    # substring
    check_regexp_hits("isa", 0, fields);
    check_regexp_hits("fox", 0, fields);
    check_regexp_hits("bear", 0, fields);
    check_regexp_hits("fish", 0, fields);

    check_regexp_hits("IsA", 3, fields);
    check_regexp_hits("Fox", 2, fields);
    check_regexp_hits("Bear", 2, fields);

    # compound
    check_regexp_hits("^this.*fox", 0, fields);
    check_regexp_hits("^this.*fox$", 0, fields);
    check_regexp_hits("^this.*bear", 0, fields);
    check_regexp_hits("^this.*bear$", 0, fields);
    check_regexp_hits("(fox$|bear$)", 0, fields);
    check_regexp_hits("is.*and", 0, fields);
    check_regexp_hits("fox.*bear", 0, fields);
    check_regexp_hits("bear.*fox", 0, fields);
    check_regexp_hits("[i]+[s]+", 3, fields);
    check_regexp_hits("[i]+[b]+", 0, fields);

    check_regexp_hits("^This.*Fox", 2, fields);
    check_regexp_hits("^This.*Fox$", 1, fields);
    check_regexp_hits("^This.*Bear", 2, fields);
    check_regexp_hits("^This.*Bear$", 2, fields);
    check_regexp_hits("(Fox$|Bear$)", 3, fields);
    check_regexp_hits("Is.*And", 1, fields);
    check_regexp_hits("Fox.*Bear", 1, fields);
    check_regexp_hits("Bear.*Fox", 0, fields);
    check_regexp_hits("[I]+[s]+", 3, fields);
    check_regexp_hits("[I]+[S]+", 0, fields);
    check_regexp_hits("[I]+[B]+", 0, fields);
  end 

  def check_uncased
    fields = ["single_scan_uncased", "single_btree_uncased", "array_slow", "array_fast", "wset_slow", "wset_fast"]
    for field in fields
      assert_hitcount(make_query(make_term(field, "thisisafox")), 3);
      assert_hitcount(make_query(make_term(field, "thisisabear")), 3);
      assert_hitcount(make_query(make_term(field, "thisisafoxandabear")), 3);
    end
    # prefix
    check_regexp_hits("^this", 3, fields);
    check_regexp_hits("^thisisafox", 2, fields);
    check_regexp_hits("^thisisafoxand", 1, fields);
    check_regexp_hits("^is", 0, fields);

    # suffix
    check_regexp_hits("fox$", 1, fields);
    check_regexp_hits("bear$", 2, fields);
    check_regexp_hits("andabear$", 1, fields);
    check_regexp_hits("fish$", 0, fields);

    # substring
    check_regexp_hits("isa", 3, fields);
    check_regexp_hits("fox", 2, fields);
    check_regexp_hits("bear", 2, fields);
    check_regexp_hits("fish", 0, fields);

    # compound
    check_regexp_hits("^this.*fox", 2, fields);
    check_regexp_hits("^this.*fox$", 1, fields);
    check_regexp_hits("^this.*bear", 2, fields);
    check_regexp_hits("^this.*bear$", 2, fields);
    check_regexp_hits("(fox$|bear$)", 3, fields);
    check_regexp_hits("is.*and", 1, fields);
    check_regexp_hits("fox.*bear", 1, fields);
    check_regexp_hits("bear.*fox", 0, fields);
    check_regexp_hits("[i]+[s]+", 3, fields);
    check_regexp_hits("[i]+[b]+", 0, fields);
    check_regexp_hits("^thisisafoxandabear.*nothere", 0, fields)

  end 

  def test_regexp
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 9, :file => selfdir + "docs.xml")
    assert_hitcount(make_query(make_term("title", "test1")), 3);
    assert_hitcount(make_query(make_term("title", "test2")), 3);
    assert_hitcount(make_query(make_term("title", "test3")), 3);
    check_uncased
    check_cased

    unless is_streaming
      # Verify that indexed fields will fallback to 'contains'.
      assert_hitcount(make_query(make_term("single_index", "thisisafox")), 3)
      assert_hitcount(make_query(make_regexp("single_index", "thisisafox")), 3)
      assert_hitcount(make_query(make_regexp("single_index", "^thisisafox")), 0)
    end

    # Invalid regexp
    assert_query_errors(make_query(make_regexp("single_index", "*")),
                        [".* Dangling meta character .* near index 0"])
  end

  def teardown
    stop
  end

end
