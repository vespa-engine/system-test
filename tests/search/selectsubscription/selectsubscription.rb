# Copyright Vespa.ai. All rights reserved.

require 'indexed_streaming_search_test'

class SelectSubscription < IndexedStreamingSearchTest

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
    # Feed 10 docs, no docs with isbn '1555844022' or 'none'
    feedoutput = feed_and_wait_for_docs("books", 0, :client => :vespa_feed_client, :file => selfdir + "books.0.json")
    assert_correct_output(["\"feeder.ok.count\" : 10"],  feedoutput)

    assert_result("query=mid:1", selfdir + "ssub.0.result.json");
    assert_result("query=mid:2", selfdir + "ssub.0.result.json");
    assert_result("query=mid:3", selfdir + "ssub.0.result.json");
  end

  def test_selectOneSubscription
    # Feed 1 doc with isbn '1555844022' and 4 with 'none'
    feedoutput = feed_and_wait_for_docs("books", 5, :client => :vespa_feed_client, :file => selfdir + "books.1.json")
    assert_correct_output(["\"feeder.ok.count\" : 5"], feedoutput)

    assert_result("query=mid:1", selfdir + "ssub.1.result.json", "title")
    assert_result("query=mid:2", selfdir + "ssub.2.result.json", "title")
    assert_result("query=mid:3", selfdir + "ssub.3.result.json", "title")
  end

  def test_selectSomeSubscriptions
    # Feed 15 docs, 1 with isbn '1555844022', 4 with 'none' and 10 with other isbns
    feedoutput = feed_and_wait_for_docs("books", 5, :client => :vespa_feed_client, :file => selfdir + "books.01.json")
    assert_correct_output(["\"feeder.ok.count\" : 15"], feedoutput)

    assert_result("query=mid:1", selfdir + "ssub.1.result.json", "title")
    assert_result("query=mid:2", selfdir + "ssub.2.result.json", "title")
    assert_result("query=mid:3", selfdir + "ssub.3.result.json", "title")
  end

  def teardown
    stop
  end

end
