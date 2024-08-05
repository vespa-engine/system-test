# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class BigIndexClosure < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
  end

  def test_big_index_closure
    deploy_app(SearchApp.new.sd(selfdir + "bigindexclosure.sd"))
    start
    feed_and_wait_for_docs("bigindexclosure", 2, :file => selfdir + "feed.json")

    for q in [ 'a:testA1', 'b:testB1', 'c:testC1', 'd:testD1', 'e:testE1',
               'f:testF1', 'g:testG1', 'h:testH1', 'i:testI1', 'j:testJ1',
               'k:testK1', 'l:testL1', 'm:testM1', 'n:testN1', 'o:testO1',
               'p:testP1', 'q:testQ1', 'r:testR1', 's:testS1', 't:testT1' ]
      check_search_doc1(q)
    end
    for q in [ 'a:testA2', 'b:testB2', 'c:testC2', 'd:testD2', 'e:testE2',
               'f:testF2', 'g:testG2', 'h:testH2', 'i:testI2', 'j:testJ2',
               'k:testK2', 'l:testL2', 'm:testM2', 'n:testN2', 'o:testO2',
               'p:testP2', 'q:testQ2', 'r:testR2', 's:testS2', 't:testT2' ]
      check_search_doc2(q)
    end
    for q in [ 'testA1', 'testB1', 'testC1', 'testD1', 'testE1',
               'testF1', 'testG1', 'testH1', 'testI1', 'testJ1',
               'testK1', 'testL1', 'testM1', 'testN1', 'testO1',
               'testP1', 'testQ1', 'testR1', 'testS1', 'testT1' ]
      check_search_doc1(q)
    end
    for q in [ 'testA2', 'testB2', 'testC2', 'testD2', 'testE2',
               'testF2', 'testG2', 'testH2', 'testI2', 'testJ2',
               'testK2', 'testL2', 'testM2', 'testN2', 'testO2',
               'testP2', 'testQ2', 'testR2', 'testS2', 'testT2' ]
      check_search_doc2(q)
    end
  end

  def check_search_doc1(query)
    check_search(query, selfdir + "doc1.result.json")
  end

  def check_search_doc2(query)
    check_search(query, selfdir + "doc2.result.json")
  end

  def check_search(query, exp_result_file)
    check_fields = [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
                     'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't' ]
    form = [[ 'query', query ], [ 'ranking', 'unranked' ]]
    encoded_form = URI.encode_www_form(form)
    assert(search(encoded_form).hit.size == 1)
    assert_result(encoded_form, exp_result_file, nil, check_fields)
  end

  def teardown
      stop
  end
end
