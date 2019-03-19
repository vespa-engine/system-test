# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

# encoding: iso8859-1
require 'indexed_search_test'

class EncodingTest < IndexedSearchTest

  def nightly?
    true
  end

  def setup
    set_owner("johansen")
    set_description("Test search and results in non-UTF8 encoding")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"simple.sd"))
    start
  end

  def test_encoding
    feed_and_wait_for_docs("simple", 3, :file => selfdir+"simple.docs.3.xml")

    wait_for_hitcount("query=test", 2)

    result = search("/?query=test")

    assert_equal(2, result.hit.size)
    assert_equal("<hi>test</hi> <hi>test</hi> document1",
                 result.hit[0].field["title"]);
    assert_equal("document2 <hi>test</hi>",
                 result.hit[1].field["title"]);

    result = search("/?query=bl%C3%A5b%C3%A6r&encoding=iso-8859-1&tracelevel=3")
    # TODO remove this debug printout and the above tracelevel when we find the bug
    if (result.hit.size != 1) then
      puts "Wrong number of hits: #{result.hit.size}"
      puts result.xmldata
    end
    assert_equal(1, result.hit.size)
    assert(result.xmldata.index("encoding=\"iso-8859-1\""))
    assert_equal("test test document1", result.hit[0].field["title"]);

    # check that raw result contains correct text:
    assert(result.xmldata.index(to_ascii_8bit("description\">Bj¯rnen spiser <hi>blÂbÊr</hi> pÂ en ¯y i nÊrheten.<")))

    # Check that it is converted correctly to UTF-8 by the XML parser.
    assert_equal(to_utf8("Bj√∏rnen spiser <hi>bl√•b√¶r</hi> p√• en √∏y i n√¶rheten."), result.hit[0].field["description"])

    result = search("/?query=bl%C3%A5b%C3%A6r&encoding=utf-8")
    assert_equal(1, result.hit.size)
    assert(result.xmldata.index("encoding=\"utf-8\""))
    assert_equal("test test document1", result.hit[0].field["title"])
    assert_equal(to_utf8("Bj√∏rnen spiser <hi>bl√•b√¶r</hi> p√• en √∏y i n√¶rheten."), result.hit[0].field["description"])

    result = search("/?query=document2&encoding=euc-jp")
    assert_equal(1, result.hit.size)
    assert(result.xmldata.index("encoding=\"euc-jp\""))
    assert_equal("<hi>document2</hi> test", result.hit[0].field["title"])
    # check that raw result contains the iso-2022-jp text:
    assert(result.xmldata.index(to_ascii_8bit("description\">π·¿Ó∏©ª∫<")))
  end

  def teardown
    stop
  end

end
