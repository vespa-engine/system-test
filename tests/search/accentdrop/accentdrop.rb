# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class AccentDrop < IndexedStreamingSearchTest

  def setup
    set_owner("baldersheim")
  end

  def test_accentdrop
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start

    feed_and_wait_for_docs("test", 6, :file => selfdir+"docs.json")

    assert_docs([1, 2], "query=s:haland&ranking=order&tracelevel=1")
    assert_docs([1, 2], "query=s:håland&ranking=order&tracelevel=1")
    assert_docs([3, 4], "query=s:orret&ranking=order&tracelevel=1")
    assert_docs([3, 4], "query=s:ørret&ranking=order&tracelevel=1")
    assert_docs([5, 6], "query=s:ære&ranking=order&tracelevel=1")
    assert_docs([5, 6], "query=s:ære&ranking=order&tracelevel=1")
  end

  def get_docid(docid)
    "id:test:test::#{docid}"
  end

  def assert_docs(exp_docids, query)
    puts "assert_docs(): exp_docids=#{exp_docids}, query='#{query}'"
    result = search(query)
    puts "result: #{result.json.to_json}"
    assert_hitcount(result, exp_docids.length)
    for i in 0...exp_docids.length do
      assert_field_value(result, "documentid", get_docid(exp_docids[i]), i)
    end
    result
  end

  def teardown
    stop
  end

end
