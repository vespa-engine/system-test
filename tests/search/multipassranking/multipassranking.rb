# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class MultipassRanking < IndexedOnlySearchTest

  def setup
    set_owner("geirst")
    set_description("Test multipass ranking with re-ranking of hits from the match data heap.")
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
  end

  def test_multipass_ranking
    feed_and_wait_for_docs("test", 4, :file => selfdir + "feed.xml")
    assert_hitcount("query=sddocname:test", 4);

    @heap_size = 2
    qp = "query=sddocname:test&parallel&skipnormalizing&ranking="

    # case 1 (x+y | x'+y and order(x) == order(x'))
    exp1 = [[4,40],[3,30],[2,20],[1,10]]
    exp2 = [[4,400],[3,300],[2,20],[1,10]]
    assert_ranking(search(qp + "r1-single"), exp1)
    assert_ranking(search(qp + "r1-multi"), exp2)

    # case 2 (x+y | x'+y and order(x) != order(x'))
    exp1 = [[4,40],[3,30],[2,20],[1,10]]
    exp2 = [[3,200],[4,100],[2,20],[1,10]]
    assert_ranking(search(qp + "r2-single"), exp1)
    assert_ranking(search(qp + "r2-multi"), exp2)

    # case 3 (case 1 + lowest(x') < highest(y))
    exp1 = [[4,400],[3,300],[2,200],[1,100]]
    exp2 = [[4,40],[3,30],[2],[1]]
    assert_ranking(search(qp + "r3-single"), exp1)
    assert_ranking(search(qp + "r3-multi"), exp2)

    # case 4 (case 2 + lowest(x') < highest(y))
    exp1 = [[1,400],[2,300],[3,200],[4,100]]
    exp2 = [[2,40],[1,30],[3],[4]]
    assert_ranking(search(qp + "r4-single"), exp1)
    assert_ranking(search(qp + "r4-multi"), exp2)

    # case 5 (x+y | x'+y and constant score)
    exp1 = [[5,10],[5,10],[5,10],[5,10]]
    exp2 = [[5,100],[5,100],[5,10],[5,10]]
    assert_ranking(search(qp + "r5-single"), exp1, true)
    assert_ranking(search(qp + "r5-multi"), exp2, true)

    qp = "query=a1:%3E20&parallel&skipnormalizing&ranking="

    # case 6 (x | x' and order(x) == order(x'))
    exp1 = [[4,40],[3,30]]
    exp2 = [[4,400],[3,300]]
    assert_ranking(search(qp + "r1-single"), exp1)
    assert_ranking(search(qp + "r1-multi"), exp2)

    # case 7 (x | x' and order(x) != order(x'))
    exp1 = [[4,40],[3,30]]
    exp2 = [[3,200],[4,100]]
    assert_ranking(search(qp + "r2-single"), exp1)
    assert_ranking(search(qp + "r2-multi"), exp2)

    # case 8 (same as case 1, but setting heap size per query)

    qp = "query=sddocname:test&parallel&skipnormalizing&ranking=r1-multi&" +
            "ranking.rerankCount="

    assert_ranking(search(qp + "0"), [[4,40],[3,30],[2,20],[1,10]])
    assert_ranking(search(qp + "1"), [[4,400],[3,30],[2,20],[1,10]])
    assert_ranking(search(qp + "2"), [[4,400],[3,300],[2,20],[1,10]])
    assert_ranking(search(qp + "3"), [[4,400],[3,300],[2,200],[1,10]])
    assert_ranking(search(qp + "4"), [[4,400],[3,300],[2,200],[1,100]])
  end

  # Asserts that the given result matches the docids and relevancy
  # of the given expected array ([[docid,relevancy],...])
  def assert_ranking(result, exp, ranking_only = false)
    assert(result.hit.size == exp.size, "Expected #{exp.size} hits, but was #{result.hit.size}")
    result.hit.each_index do |i|
      if (!ranking_only)
        docid = result.hit[i].field["documentid"]
        exp_docid = "id:test/test:test::#{exp[i][0]}"
        assert(docid == exp_docid, "Expected document id '#{exp_docid} for hit #{i}, but was #{docid}")
      end
      if (exp[i].size == 2)
        score = result.hit[i].field["relevancy"].to_i
        exp_score = exp[i][1]
        assert(score == exp_score, "Expected relevancy #{exp_score} for hit #{i}, but was #{score}")
      end
    end
  end

  def teardown
    stop
  end

end
