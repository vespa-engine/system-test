# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'
require 'rexml/document'

class MultipleDocumentTypes < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
  end

  def extract_group(res)
    json = JSON.parse(res.xmldata)
    root = json['root']
    assert(root)
    children = root['children']
    assert(children)
    assert(children.size > 0)
    children.each do |child|
      return child if ('group:root:0' == child['id'])
    end
    assert(false, "Missing group:root:0 in #{children}")
  end

  def test_one_search_cluster
    timeout = 5.0
    set_description("Test that we can have a search cluster with native support for multiple document types")
    set_expected_logged(/proton\.groupingmanager.*Could not locate attribute for grouping number 0 : Failed locating attribute vector 'pages'/)
    deploy_app(SearchApp.new.sd(selfdir+"common.sd").sd(selfdir+"book.sd").sd(selfdir+"music.sd").sd(selfdir+"video.sd"))
    start
    feedfile(selfdir + "feed2.json")
    wait_for_hitcount("query=sddocname:book", 5)
    wait_for_hitcount("query=sddocname:music", 4)
    wait_for_hitcount("query=sddocname:video", 4)

    query = "query=year:%3E1980&ranking=year"
    fields = ["relevancy","sddocname","title","year","author","artist","director","documentid"]
    # restrict to one document type
    assert_result(query + "&restrict=book",  selfdir + "result.book.all.json", nil, fields)
    assert_result(query + "&restrict=music", selfdir + "result.music.all.json", nil, fields)
    assert_result(query + "&restrict=video", selfdir + "result.video.all.json", nil, fields)

    # search all document types
    assert_result("query=year:%3C2010&ranking=year&hits=4", selfdir + "result.all.json", nil, fields)
    assert_result("query=year:%3E1982&ranking=unranked&hits=4&sorting=%2Byear", selfdir + "result.all.sort.json", nil, fields)
    result = search('query=stallone&ranking=year')
    assert_equal('id:video:video::0', result.hit[0].field['documentid'])
    assert_equal('id:book:book::4', result.hit[1].field['documentid'])
    result = search('query=author:stallone&ranking=year')
    assert_equal('id:book:book::4', result.hit[0].field['documentid'])

    # test offset and hits when using relevancy as ordering
    query = "query=year:%3E1981&ranking=year"
    assert_subset([2010,2009,2008,2007], query, 0, 4)
    assert_subset([2008,2007,2005,2001], query, 2, 4)
    assert_subset([2005,2001,1999,1996], query, 4, 4)
    assert_subset([1999,1996,1995,1994], query, 6, 4)
    assert_subset([1995,1994,1988,1982], query, 8, 4)
    assert_subset([1988,1982],           query, 10, 4)
    assert_subset([],                    query, 12, 4)

    # test offset and hits when using sorting
    query = "query=year:%3C2010&ranking=year&sorting=%2Byear"
    assert_subset([1981,1982,1988,1994], query, 0, 4)
    assert_subset([1988,1994,1995,1996], query, 2, 4)
    assert_subset([1995,1996,1999,2001], query, 4, 4)
    assert_subset([1999,2001,2005,2007], query, 6, 4)
    assert_subset([2005,2007,2008,2009], query, 8, 4)
    assert_subset([2008,2009],           query, 10, 4)
    assert_subset([],                    query, 12, 4)

    # test simple 1 level grouping
    query = "query=year:%3E1980&ranking=year&select=all(group(rating) each(output(count())))&hits=0"
    assert_xml_result_with_timeout(timeout, query + "&restrict=video", selfdir + "result.video.grouping.xml")
    assert_xml_result_with_timeout(timeout, query, selfdir + "result.all.grouping.xml")

    # test simple 2 level grouping
    query = "?query=year:%3E1980&ranking=year&select=all(group(rating) each(group(pages) each(output(count()))))&hits=0"
    assert_xml_result_with_timeout(timeout, query + "&restrict=book", selfdir + "result.book.grouping.2.xml")
    # only type book has both attribute rating & pages
    res_one = search(query + '&restrict=book&format=json')
    res_both = search(query + '&format=json')
    assert_equal(5, res_one.hitcount)
    assert_equal(13, res_both.hitcount)
    group_one = extract_group(res_one)
    group_both = extract_group(res_both)
    assert_equal(group_one, group_both)
  end

  def assert_subset(exp_values, query, offset, hits)
    query = query + "&offset=#{offset}&hits=#{hits}"
    puts "assert_subset: expected[#{exp_values.join(',')}], #{query}"
    result = search(query)
    assert_equal(12, result.hitcount)
    assert_equal(exp_values.size, result.hit.size)
    for i in 0...exp_values.size do
      assert_equal(exp_values[i], result.hit[i].field["year"].to_i)
    end
  end

  def teardown
    stop
  end

end
