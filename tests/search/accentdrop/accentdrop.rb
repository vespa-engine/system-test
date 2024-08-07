# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class AccentDrop < IndexedStreamingSearchTest

  def setup
    set_owner("baldersheim")
  end

  def test_accentdrop
    deploy_app(SearchApp.new.sd(selfdir+"test.sd"))
    start

    feed_and_wait_for_docs("test", 6, :file => selfdir+"docs.json")

    # Just document in test how qrs normalizes
    assert_exact_docs([], 'query=øker været håpet&ranking=order&tracelevel=1')
    assert_query_self

    #assert_contains_docs([1, 2], "query=s:haland&ranking=order&tracelevel=1")
    #assert_contains_docs([3, 4], "query=s:orret&ranking=order&tracelevel=1")
    #assert_contains_docs([5, 6], "query=s:vere&ranking=order&tracelevel=1")
  end

  def assert_query_self
    assert_contains([2], "håland")
    assert_contains([4], "ørret")
    assert_contains([6], "være")
  end

  def assert_contains(exp_docids, term)
    assert_contains_docs(exp_docids, "query=s_a:#{term}&ranking=order&tracelevel=1")
    assert_contains_docs(exp_docids, "query=s_f:#{term}&ranking=order&tracelevel=1")
    assert_contains_docs(exp_docids, "query=s:#{term}&ranking=order&tracelevel=1")
  end

  def get_docid(docid)
    "id:test:test::#{docid}"
  end

  def assert_exact_docs(exp_docids, query)
    puts "assert_exact_docs(): exp_docids=#{exp_docids}, query='#{query}'"
    result = search(query)
    puts "result: #{result.json.to_json}"
    assert_hitcount(result, exp_docids.length)
    for i in 0...exp_docids.length do
      assert_field_value(result, "documentid", get_docid(exp_docids[i]), i)
    end
    result
  end

  def assert_contains_docs(exp_docids, query)
    puts "assert_contains_docs(): exp_docids=#{exp_docids}, query='#{query}'"
    result = search(query)
    puts "result: #{result.json.to_json}"
    assert(result.hitcount >= exp_docids.length)
    for i in 0...exp_docids.length do
      assert(count_hits_with_field_value(result, "documentid", get_docid(exp_docids[i])) == 1, "Did not find #{exp_docids[i]}")
    end
    result
  end

  def teardown
    stop
  end

end
