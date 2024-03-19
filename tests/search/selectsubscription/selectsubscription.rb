# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class SelectSubscription < IndexedSearchTest

  def setup
    set_owner("musum")
    deploy_app(SearchApp.new.cluster(
                        SearchCluster.new("books1").sd(selfdir + "books.sd").
                        doc_type('books', 'books.isbn=="1555844022"')).
                      cluster(
                        SearchCluster.new("books2").sd(selfdir + "books.sd").
                        doc_type('books', 'books.isbn="none"')))
    start
  end

  def test_selectNoSubscriptions
    feedoutput = feed_and_wait_for_docs("books", 0, :file => selfdir + "books.0.json", :clusters => [ "books1", "books2" ], :exceptiononfailure => false);
    assert_correct_output(["ok: 0"],  feedoutput)
    assert_correct_output(["ignored: 10"],  feedoutput)

    #save_result("query=mid:1", selfdir + "ssub.0.result.json")

    assert_result("query=mid:1", selfdir + "ssub.0.result.json");
    assert_result("query=mid:2", selfdir + "ssub.0.result.json");
    assert_result("query=mid:3", selfdir + "ssub.0.result.json");
  end

  def test_selectOneSubscription
    feedoutput = feed_and_wait_for_docs("books", 5, :file => selfdir + "books.1.json", :clusters => [ "books1", "books2" ], :exceptiononfailure => false)
    assert_correct_output(["ok: 5"], feedoutput)

    assert_result("query=mid:1", selfdir + "ssub.1.result.json", "title")
    assert_result("query=mid:2", selfdir + "ssub.2.result.json", "title")
    assert_result("query=mid:3", selfdir + "ssub.3.result.json", "title")
  end

  def test_selectSomeSubscriptions
    feedoutput = feed_and_wait_for_docs("books", 5, :file => selfdir + "books.01.json", :clusters => [ "books1", "books2" ], :exceptiononfailure => false);
    assert_correct_output(["ok: 5"], feedoutput)
    assert_correct_output(["ignored: 10"], feedoutput)

    #save_result("query=mid:1", selfdir + "ssub.1.result.json")
    #save_result("query=mid:2", selfdir + "ssub.2.result.json")
    #save_result("query=mid:3", selfdir + "ssub.3.result.json")

    assert_result("query=mid:1", selfdir + "ssub.1.result.json", "title")
    assert_result("query=mid:2", selfdir + "ssub.2.result.json", "title")
    assert_result("query=mid:3", selfdir + "ssub.3.result.json", "title")
  end

  def teardown
    stop
  end

end
