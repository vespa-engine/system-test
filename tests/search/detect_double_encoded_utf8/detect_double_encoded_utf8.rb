# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class DetectDoubleEncodedUtf < IndexedSearchTest

  def setup
    set_owner("arnej")
    set_description("Check input sanity.");
    search_chain = SearchChain.new("default", "native").
      add(Searcher.new("com.yahoo.search.searchers.InputCheckingSearcher",
          nil, nil, "com.yahoo.search.searchers.InputCheckingSearcher",
          "container-search-and-docproc"))
    deploy_app(SearchApp.new.sd(SEARCH_DATA+"music.sd").search_chain(search_chain))
    start
    feed_and_wait_for_docs("music", 10, { :file => SEARCH_DATA+"music.10.xml" })
  end

  def test_double_encoded_utf_is_rejected
    result = search("/?query=nosuchterm&fetchpeakqps")
    assert_query_no_errors("/search/?query=a+a+a+a+a+a")
    # >>> input = "ååååå".decode("utf-8")
    # >>> input.encode("utf-8")
    # '\xc3\xa5\xc3\xa5\xc3\xa5\xc3\xa5\xc3\xa5'
    # >>> u'\xc3\xa5\xc3\xa5\xc3\xa5\xc3\xa5\xc3\xa5'.encode("UTF-8")
    # '\xc3\x83\xc2\xa5\xc3\x83\xc2\xa5\xc3\x83\xc2\xa5\xc3\x83\xc2\xa5\xc3\x83\xc2\xa5'
    # >>> urllib.quote(_)
    # '%C3%83%C2%A5%C3%83%C2%A5%C3%83%C2%A5%C3%83%C2%A5%C3%83%C2%A5'
    assert_query_errors("/search/?query=%C3%83%C2%A5%C3%83%C2%A5%C3%83%C2%A5%C3%83%C2%A5%C3%83%C2%A5", [
        ".* double encoded UTF-8.*"])
  end

  def teardown
    stop
  end

end
