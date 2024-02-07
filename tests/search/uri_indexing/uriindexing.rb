# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class UriIndexing < IndexedOnlySearchTest

  def setup
    set_owner("yngve")
    set_description("Query: Search for full url / and check that port " +
                    "number 80 and 443 is ignored")
  end

  def test_uri_indexing_simple
    try_type("simple")
  end

  def test_uri_indexing_array
    try_type("array")
  end

  def test_uri_indexing_array_add
    try_type("array_add")
  end

  def test_uri_reject_invalid
    set_owner("yngve")
    deploy_app(SearchApp.new.sd("#{selfdir}/simple_def.sd"))
    start
    assert_raise(ExecuteError) do
      feed(:file => "#{selfdir}/invalidurl_feed.xml")
    end
  end

  def try_type(type)
    deploy_app(SearchApp.new.sd("#{selfdir}/#{type}_def.sd"))
    start
    feed_and_wait_for_docs("#{type}_def", 7, :file => "#{selfdir}/#{type}_feed.xml")

    puts "Query: Search for full url / and check that port number 80 and " +
      "443 is ignored"
    assert_search('query=surl:http://shopping.yahoo-inc.com/shop?d=hab%26' +
                  'id=1804905709%26cat=100%23frag1',
                  [ "Blues1", "Blues2", "Blues3" ])
    assert_search('query=url:http://shopping.yahoo-inc.com/shop?d=hab%26' +
                  'id=1804905709%26cat=100%23frag1',
                  [ "Blues1", "Blues2", "Blues3" ])

    puts "Query: Search for hostname, implicit anchoring"
    assert_search('query=surl.hostname:shopping.yahoo.com',
                  [ "Chicago Blues", "Classic Female Blues" ])
    assert_search('query=surl.hostname:yahoo.com',
                  [ "Chicago Blues", "Classic Female Blues",
                    "Contemporary Blues" ])
    assert_search('query=surl.hostname:yahoo', [])

    puts "Query: Search for hostname, explicit anchor at start"
    assert_search('query=surl.hostname:%5Eyahoo', [])

    puts "Query: Search for hostname, explicit not anchor at end"
    assert_search('query=surl.hostname:yahoo%2A',
                  [ "Chicago Blues", "Classic Female Blues",
                    "Contemporary Blues" ])

    puts "Query: Search for hostname, explicit not anchor at end, " +
      "explicit anchor at start"
    assert_search('query=surl.hostname:%5Eshopping.yahoo%2A',
                  [ "Chicago Blues", "Classic Female Blues" ])

    puts "Query: Search for hostname, with alias"
    assert_search('query=site:shopping.yahoo-inc.com',
                  [ "Blues1", "Blues2", "Blues3" ])

    puts "Query: Search for scheme"
    assert_search('query=surl.scheme:http',
                  [ "Blues1", "Blues2", "Blues3", "Chicago Blues",
                    "Classic Female Blues", "Contemporary Blues",
                    "Entity Blues" ])

    puts "Query: Search for port"
    assert_search('query=surl.port:8080',
                  [ "Classic Female Blues" ])

    puts "Query: Search for path"
    assert_search('query=surl.path:yahoo/shop', [ "Classic Female Blues" ])
    assert_search('query=surl.path:Yahoo/shop', [ "Classic Female Blues" ])

    puts "Query: Search for query"
    assert_search('query=surl.query:d=hab%26id=1804905710',
                  [ "Chicago Blues" ])

    puts "Query: Search for fragment"
    assert_search('query=surl.fragment:frag1',
                  [ 'Blues1', 'Blues2', 'Blues3' ])

    puts "Query: Search for url with entities"
    assert_search('query=surl:http%3A//www.handelsblatt.com/pshb/fn/relhbi'+
                  '/sfn/buildhbi/GoPage/202829%2C202148/id/921463/SH/0/dep'+
                  'ot/0/%26bdquo%3BPhantastische_Mini-WM%26ldquo%3B',
                  [ 'Entity Blues' ])

    puts "Query: Search for document containing invalid url. Should be indexed, without the url. (bug #2466528)"
    assert_hitcount("query=surl:host:datelcustomerservice.com", 0)
  end

  def assert_search(query, expected_result)
    result = search("/?" + query)
    titles = []
    result.hit.each { |hit|
      titles.push(hit.field["title"].to_s)
    }
    assert_equal(expected_result, titles.sort)
  end

  def teardown
    stop
  end

end
