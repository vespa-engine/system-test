# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
# encoding: utf-8
require 'indexed_search_test'

class SpecialTokens < IndexedSearchTest

  def setup
    set_owner("johansen")
    deploy_app(SearchApp.new.
               sd("#{selfdir}/specialtokens.sd").
               config(ConfigOverride.new("vespa.configdefinition.specialtokens").
                      add(ArrayConfig.new("tokenlist").append.
                          add(0, ConfigValue.new("name", "default")).
                          add(0, ArrayConfig.new("tokens").append.
                              add( 0, ConfigValue.new("token", "c++")).
                              add( 1, ConfigValue.new("token", "wal-mart")).
                              add( 1, ConfigValue.new("replace", "walmart")).
                              add( 2, ConfigValue.new("token", ".net")).
                              add( 3, ConfigValue.new("token", "-索")).
                              add( 4, ConfigValue.new("token", "sony")).
                              add( 4, ConfigValue.new("replace", "索尼")).
                              add( 5, ConfigValue.new("token", "dvd+-r")).
                              add( 6, ConfigValue.new("token", "dvd±r")).
                              add( 7, ConfigValue.new("token", "dvdplusminusr")).
                              add( 7, ConfigValue.new("replace", "dvd+-r")).
                              add( 8, ConfigValue.new("token", " token_with_space")).
                              add( 9, ConfigValue.new("token", "!token_with_exclamation")).
                              add(10, ConfigValue.new("token", "<![CDATA[&token_with_ampersand]]>")).
                              add(11, ConfigValue.new("token", "*token_with_asterisk")).
                              add(12, ConfigValue.new("token", "<![CDATA[&]]>")).
                              add(12, ConfigValue.new("replace", "and")).
                              add(13, ConfigValue.new("token", "TOKEN_IN_CAPITALS"))))))
    start
  end

  def test_one_specialtoken
    feed_and_wait_for_docs("specialtokens", 1, :file => "#{selfdir}/docs.1.xml")
    puts "test queries..."
    assert_hitcount("query=content:foo",     1)
    assert_hitcount("query=content:c%2B%2B", 1)
    assert_hitcount("query=content:c",       0)

    #Searching for &amp;
    assert_hitcount("query=content:%26",       1)

    res = "#{selfdir}/output/"
    assert_result("query=content:foo",        "#{res}/one-a.xml")
    assert_result("query=content:c%2B%2B",    "#{res}/one-b.xml")
    assert_result("query=content:c",          "#{res}/one-c.xml")
  end

  def test_uppercase_specialtoken
    # some libraries linguistics will lowercase strings before passing them through the fsa,
    # meaning that special tokens with capital letters WILL NOT be found.
    feed_and_wait_for_docs("specialtokens", 18, :file => "#{selfdir}/docs.xml")

    assert_hitcount("query=content:TOKEN_IN_CAPITALS", 0)
  end

  def test_specialtokens
    feed_and_wait_for_docs("specialtokens", 18, :file => "#{selfdir}/docs.xml")

    res = "#{selfdir}/output/specialtokens"
    puts "test queries..."
    f1 = ["content"]
    f2 = ["content", "jcontent"]
    assert_result("query=content:foo",        "#{res}.1.result.xml", "id", f1)
    assert_result("query=content:c%2B%2B",    "#{res}.2.result.xml", "id", f2)
    assert_result("query=content:%2Enet",     "#{res}.3.result.xml", "id", f2)
    assert_result("query=content:c",          "#{res}.4.result.xml", "id", f1)
    assert_result("query=content:net",        "#{res}.5.result.xml", "id", f1)
    assert_result("query=content:wal%2Dmart", "#{res}.6.result.xml", "id", f1)
    assert_result("query=content:walmart",    "#{res}.7.result.xml", "id", f1)
    assert_result("query=content:wal",        "#{res}.8.result.xml", "id", f1)
    assert_result("query=-%E7%B4%A2",         "#{res}.9.result.xml", "id", f2)

    # Tests that special tokens are matched also on non-boundaries for cjk languages
    # &#32034;&#23612; (second query) is replaced by "sony" by the special tokens,
    # so if this is matched as a special token, these should both return
    # the same result, which is the document containing &#32034;&#23612;&#25163;&#26426
    # and the one containing sony&#25163;&#26426
    assert_result("query=sony%E6%89%8B%E6%9C%BA&language=zh-hans",
                  "#{res}.cjk.result.xml", "id", f1)
    assert_result("query=%E7%B4%A2%E5%B0%BC%E6%89%8B%E6%9C%BA&language=zh-hans",
                  "#{res}.cjk.inversed.result.xml", "id", f1)
    # Same two queries without the second token following the two sony synonyms
    assert_result("query=%E7%B4%A2%E5%B0%BC&language=zh-hans",
                  "#{res}.cjk.result.xml", "id", f1)
    assert_result("query=sony&language=zh-hans",
                  "#{res}.cjk.result.xml", "id", f1)
    # Verify that special token matching inside tokens also happens when there is
    # text without a token boundary  (ab) in front of the special token
    assert_result("query=absony%E6%89%8B%E6%9C%BA&language=zh-hans",
                  "#{res}.cjk.justone.result.xml", "id", f1)
    # Verify that this only happen for cjk - absony should not be split without
    # language=zh-hans
    result = search("absony&tracelevel=1")
    assert (result.xmldata.include? "query=[absony]")

    # used to trigger bugs, should work now:
    assert_hitcount("query=content:walmart", 2)
    assert_hitcount("query=content:wal-mart", 2)
    assert_hitcount("query=content:wal.mart", 1)
    assert_hitcount("query=content:%22wal mart%22", 1)

    # used to trigger bugs, should work now:
    assert_hitcount("query=content:dvdplusminusr", 2)
    assert_hitcount("query=content:dvd%2B%2Dr", 2)

    pm = "%C2%B1"
    assert_hitcount("query=content:dvd#{pm}r", 1)
    assert_hitcount("query=content:DVD#{pm}R", 1)
    assert_hitcount("query=content:dvd#{pm}R", 1)
    assert_hitcount("query=content:DVD#{pm}r", 1)

    assert_hitcount("query=content:DVD", 0)
    assert_hitcount("query=content:dvd", 0)

    assert_hitcount("query=content:token_with_space", 0)
    assert_hitcount("query=content:%20token_with_space", 1)
    assert_hitcount("query=content:token_with_exclamation", 0)
    assert_hitcount("query=content:%21token_with_exclamation", 1)
    assert_hitcount("query=content:token_with_ampersand", 0)
    assert_hitcount("query=content:%26token_with_ampersand", 1)
    assert_hitcount("query=content:token_with_asterisk", 0)
    assert_hitcount("query=content:%2Atoken_with_asterisk", 1)
  end

  def teardown
    stop
  end

end
