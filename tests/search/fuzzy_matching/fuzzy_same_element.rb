# Copyright Vespa.ai. All rights reserved.
require 'indexed_search_test'
require 'cgi'

# sameElement+fuzzy is in a dedicated test that does _not_ check streaming mode,
# as this combination does not currently work.
# TODO make it work with both modes and move to other test.
class FuzzySameElementSearch < SearchTest

  def setup
    set_owner('vekterli')
  end

  def teardown
    stop
  end

  def make_query(a)
    yql_query = CGI::escape("select * from sources * where #{a}")
    my_query = "query=" + yql_query + "&type=yql"
    my_query
  end

  def assert_documents(query, exp_docids)
    result = search(query)
    assert_hitcount(result, exp_docids.size)
    result.sort_results_by("documentid")
    for i in 0...exp_docids.size do
      exp_docid = "id:test:test::#{exp_docids[i]}"
      assert_field_value(result, "documentid", exp_docid, i)
    end
  end

  def assert_fuzzy_same_element(max_edits, term1, term2, expected_docs)
    q = "my_struct_array contains sameElement(" +
        "f1 contains ({maxEditDistance:#{max_edits}}fuzzy(\"#{term1}\")), " +
        "f2 contains ({maxEditDistance:#{max_edits}}fuzzy(\"#{term2}\")))"
    assert_documents(make_query(q), expected_docs)
  end

  def test_fuzzysearch_with_sameelement
    set_description('Test that the fuzzy() operator can be used as part of sameElement')
    deploy_app(SearchApp.new.sd(selfdir+'test.sd'))
    start
    feed_and_wait_for_docs('test', 6, :file => selfdir + 'docs.json')

    assert_fuzzy_same_element(1, 'aax', 'bbx', [1])
    assert_fuzzy_same_element(2, 'aax', 'bbx', [1, 2])
    assert_fuzzy_same_element(2, 'aax', 'ddx', [2])
  end

end
