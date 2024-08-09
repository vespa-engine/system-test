# encoding: iso-8859-1
require 'indexed_streaming_search_test'

class EncodingTest < IndexedStreamingSearchTest

  def setup
    set_owner("arnej")
    set_description("Test search and results in non-UTF8 encoding")
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"simple.sd"))
    start
  end

  def test_encoding
    feed_and_wait_for_docs("simple", 3, :file => selfdir+"simple.docs.3.json")

    wait_for_hitcount("query=test", 2)

    result = search("/?query=test&format=xml")

    assert_equal(2, result.hit.size)
    assert_equal("<hi>test</hi> <hi>test</hi> document1",
                 result.hit[0].field["title"]);
    assert_equal("document2 <hi>test</hi>",
                 result.hit[1].field["title"]);

    result = search("/?query=bl%C3%A5b%C3%A6r&encoding=iso-8859-1&tracelevel=3&format=xml")
    assert_equal(1, result.hit.size)
    assert(result.xmldata.index("encoding=\"iso-8859-1\""))
    assert_equal("test test document1", result.hit[0].field["title"]);
    puts("hit[0].description=" + result.hit[0].field["description"].to_s)

    # check that raw result contains correct text:
    assert(result.xmldata.index(to_ascii_8bit("description\">Bjørnen spiser <hi>blåbær</hi> på en øy i nærheten.<")))

    # Check that it is converted correctly to UTF-8 by the XML parser.
    assert_equal(to_utf8("BjÃ¸rnen spiser <hi>blÃ¥bÃ¦r</hi> pÃ¥ en Ã¸y i nÃ¦rheten."), result.hit[0].field["description"])

    result = search("/?query=bl%C3%A5b%C3%A6r&encoding=utf-8&format=xml")
    assert_equal(1, result.hit.size)
    assert(result.xmldata.index("encoding=\"utf-8\""))
    assert_equal("test test document1", result.hit[0].field["title"])
    assert_equal(to_utf8("BjÃ¸rnen spiser <hi>blÃ¥bÃ¦r</hi> pÃ¥ en Ã¸y i nÃ¦rheten."), result.hit[0].field["description"])

    result = search("/?query=document2&encoding=euc-jp&format=xml")
    assert_equal(1, result.hit.size)
    assert(result.xmldata.index("encoding=\"euc-jp\""))
    assert_equal("<hi>document2</hi> test", result.hit[0].field["title"])
    # check that raw result contains the iso-2022-jp text:
    assert(result.xmldata.index(to_ascii_8bit("description\">¹áÀî¸©»º<")))
  end

  def teardown
    stop
  end

end
